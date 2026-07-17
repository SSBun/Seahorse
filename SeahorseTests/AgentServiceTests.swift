#if os(macOS)

import Foundation
import XCTest
@testable import Seahorse

final class AgentServiceTests: XCTestCase {
    override func tearDown() {
        AgentURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSendPostsAuthenticatedAgentRequestAndDecodesBookmarkIDs() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let sessionID = UUID(uuidString: "00000000-0000-4000-8000-000000000010")!
        let bookmarkID = UUID(uuidString: "00000000-0000-4000-8000-000000000020")!
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            apiToken: "api-token",
            apiBaseURL: "https://example.com/v1",
            model: "test-model"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, endpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer internal-token")

            let body = try request.bodyData()
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["sessionId"] as? String, sessionID.uuidString)
            XCTAssertEqual(object["message"] as? String, "Find Swift bookmarks")
            let aiConfiguration = try XCTUnwrap(object["configuration"] as? [String: String])
            XCTAssertEqual(aiConfiguration["provider"], "openai-compatible")
            XCTAssertEqual(aiConfiguration["apiToken"], "api-token")
            XCTAssertEqual(aiConfiguration["apiBaseURL"], "https://example.com/v1")
            XCTAssertEqual(aiConfiguration["model"], "test-model")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = try JSONEncoder().encode(
                AgentSearchResponse(answer: "Found one.", bookmarkIDs: [bookmarkID])
            )
            return (response, data)
        }

        let service = AgentService(
            session: urlSession,
            configurationProvider: { configuration }
        )
        let response = try await service.send("Find Swift bookmarks", to: sessionID)

        XCTAssertEqual(response.answer, "Found one.")
        XCTAssertEqual(response.bookmarkIDs, [bookmarkID])
    }

    func testSendCodexRequestDoesNotIncludeAPIKeyConfiguration() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            provider: .openAICodex,
            model: "gpt-5.4-mini"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            let body = try request.bodyData()
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let aiConfiguration = try XCTUnwrap(object["configuration"] as? [String: String])
            XCTAssertEqual(aiConfiguration["provider"], "openai-codex")
            XCTAssertEqual(aiConfiguration["model"], "gpt-5.4-mini")
            XCTAssertNil(aiConfiguration["apiToken"])
            XCTAssertNil(aiConfiguration["apiBaseURL"])

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = try JSONEncoder().encode(
                AgentSearchResponse(answer: "Connected.", bookmarkIDs: [])
            )
            return (response, data)
        }

        let service = AgentService(session: urlSession, configurationProvider: { configuration })
        let response = try await service.send("Hello", to: UUID())

        XCTAssertEqual(response.answer, "Connected.")
    }

    func testSendEncodesClaudeCompatibleConfiguration() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            provider: .claudeCompatible,
            apiToken: "claude-token",
            apiBaseURL: "https://claude.example.com",
            model: "claude-model"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            let body = try request.bodyData()
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let aiConfiguration = try XCTUnwrap(object["configuration"] as? [String: String])
            XCTAssertEqual(aiConfiguration["provider"], "claude-compatible")
            XCTAssertEqual(aiConfiguration["apiToken"], "claude-token")
            XCTAssertEqual(aiConfiguration["apiBaseURL"], "https://claude.example.com")
            XCTAssertEqual(aiConfiguration["model"], "claude-model")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: endpoint,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            let data = try JSONEncoder().encode(
                AgentSearchResponse(answer: "Claude connected.", bookmarkIDs: [])
            )
            return (response, data)
        }

        let service = AgentService(session: urlSession, configurationProvider: { configuration })
        let response = try await service.send("Hello", to: UUID())

        XCTAssertEqual(response.answer, "Claude connected.")
    }

    func testStartCodexConnectionUsesInternalAuthenticationAndDecodesBrowserURL() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            model: "test-model"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/agent/auth/codex")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer internal-token")

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )
            )
            return (
                response,
                Data(#"{"authorizationURL":"https://auth.openai.com/authorize"}"#.utf8)
            )
        }

        let service = AgentService(session: urlSession, configurationProvider: { configuration })

        let authorizationURL = try await service.startCodexConnection()
        XCTAssertEqual(authorizationURL, URL(string: "https://auth.openai.com/authorize"))
    }

    func testCodexModelsUsesInternalCatalogEndpoint() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            model: "test-model"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/agent/providers/codex/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer internal-token")
            let response = try XCTUnwrap(
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            return (
                response,
                Data(#"[{"id":"gpt-5.4","name":"GPT-5.4","supportsImageGeneration":true}]"#.utf8)
            )
        }

        let service = AgentService(session: urlSession, configurationProvider: { configuration })
        let models = try await service.codexModels()

        XCTAssertEqual(
            models,
            [CodexModelDescriptor(id: "gpt-5.4", name: "GPT-5.4", supportsImageGeneration: true)]
        )
    }

    func testGenerateCodexImagePostsPromptAndDecodesImage() async throws {
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:17373/agent"))
        let configuration = AgentServiceConfiguration(
            endpoint: endpoint,
            internalToken: "internal-token",
            model: "test-model"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [AgentURLProtocol.self]
        let urlSession = URLSession(configuration: sessionConfiguration)

        AgentURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/agent/images/codex")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 330)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer internal-token")
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: request.bodyData()) as? [String: String]
            )
            XCTAssertEqual(object, [
                "model": "gpt-5.4",
                "prompt": "A seahorse",
                "referenceImageBase64": "cmVmZXJlbmNl"
            ])
            let response = try XCTUnwrap(
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            return (response, Data(#"{"imageBase64":"aW1hZ2U="}"#.utf8))
        }

        let service = AgentService(session: urlSession, configurationProvider: { configuration })
        let data = try await service.generateCodexImage(
            prompt: "A seahorse",
            model: "gpt-5.4",
            referenceImageData: Data("reference".utf8)
        )

        XCTAssertEqual(data, Data("image".utf8))
    }
}

private final class AgentURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    func bodyData() throws -> Data {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            throw URLError(.badServerResponse)
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4_096)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(buffer, maxLength: 4_096)
            if count < 0 {
                throw httpBodyStream.streamError ?? URLError(.cannotDecodeContentData)
            }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

#endif
