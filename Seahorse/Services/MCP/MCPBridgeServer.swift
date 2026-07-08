#if os(macOS)
import Foundation
import Network

@MainActor
final class MCPBridgeServer {
    static let shared = MCPBridgeServer()

    private let settings: MCPSettings
    private let bridgeService: MCPBookmarkBridgeService
    private let queue = DispatchQueue(label: "com.seahorse.mcp.bridge")
    private var listener: NWListener?
    private var connections: [UUID: MCPBridgeConnection] = [:]

    private init() {
        settings = .shared
        bridgeService = MCPBookmarkBridgeService()
    }

    func start() throws {
        guard listener == nil else { return }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(MCPSettings.mcpHost),
            port: NWEndpoint.Port(rawValue: UInt16(MCPSettings.bridgePort))!
        )

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection)
            }
        }
        listener.stateUpdateHandler = { state in
            if case .failed = state {
                Task { @MainActor in
                    self.stop()
                }
            }
        }

        self.listener = listener
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        let id = UUID()
        let bridgeConnection = MCPBridgeConnection(
            connection: connection,
            internalToken: settings.internalToken,
            bridgeService: bridgeService,
            onClose: { [weak self] in
                Task { @MainActor in
                    self?.connections.removeValue(forKey: id)
                }
            }
        )
        connections[id] = bridgeConnection
        bridgeConnection.start(queue: queue)
    }
}

private final class MCPBridgeConnection {
    private let connection: NWConnection
    private let internalToken: String
    private let bridgeService: MCPBookmarkBridgeService
    private let onClose: () -> Void
    private var buffer = Data()

    init(
        connection: NWConnection,
        internalToken: String,
        bridgeService: MCPBookmarkBridgeService,
        onClose: @escaping () -> Void
    ) {
        self.connection = connection
        self.internalToken = internalToken
        self.bridgeService = bridgeService
        self.onClose = onClose
    }

    func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receive()
            case .failed, .cancelled:
                self?.onClose()
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        connection.cancel()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data {
                self.buffer.append(data)
            }

            if let error {
                self.send(status: 500, body: ["error": "Bridge receive failed: \(error.localizedDescription)"])
                return
            }

            if let request = self.parseRequest() {
                self.handle(request)
                return
            }

            if self.buffer.count > 1_048_576 {
                self.send(status: 413, body: ["error": "Request body too large"])
                return
            }

            if isComplete {
                self.send(status: 400, body: ["error": "Malformed HTTP request"])
                return
            }

            self.receive()
        }
    }

    private func parseRequest() -> BridgeHTTPRequest? {
        guard let headerRange = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = buffer[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = headerRange.upperBound
        guard buffer.count >= bodyStart + contentLength else { return nil }

        let body = Data(buffer[bodyStart..<(bodyStart + contentLength)])
        return BridgeHTTPRequest(
            method: String(requestParts[0]),
            path: String(requestParts[1]),
            headers: headers,
            body: body
        )
    }

    private func handle(_ request: BridgeHTTPRequest) {
        guard request.method == "POST" else {
            send(status: 405, body: ["error": "Method not allowed"])
            return
        }
        guard request.path == "/bridge" else {
            send(status: 404, body: ["error": "Not found"])
            return
        }
        guard request.headers["authorization"] == "Bearer \(internalToken)" else {
            send(status: 401, body: ["error": "Unauthorized"])
            return
        }

        Task { @MainActor in
            do {
                let bridgeRequest = try JSONDecoder().decode(MCPBridgeRequest.self, from: request.body)
                let response = await bridgeService.handle(bridgeRequest)
                let data = try JSONEncoder().encode(response)
                send(status: response.ok ? 200 : 400, data: data)
            } catch {
                send(status: 400, body: ["error": error.localizedDescription])
            }
        }
    }

    private func send(status: Int, body: [String: String]) {
        let data = (try? JSONEncoder().encode(body)) ?? Data("{}".utf8)
        send(status: status, data: data)
    }

    private func send(status: Int, data: Data) {
        let reason = HTTPReason.phrase(for: status)
        var response = Data("HTTP/1.1 \(status) \(reason)\r\n".utf8)
        response.append(Data("Content-Type: application/json\r\n".utf8))
        response.append(Data("Content-Length: \(data.count)\r\n".utf8))
        response.append(Data("Connection: close\r\n\r\n".utf8))
        response.append(data)

        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
            self?.onClose()
        })
    }
}

private struct BridgeHTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

private enum HTTPReason {
    static func phrase(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 413: "Payload Too Large"
        case 500: "Internal Server Error"
        default: "HTTP"
        }
    }
}
#endif
