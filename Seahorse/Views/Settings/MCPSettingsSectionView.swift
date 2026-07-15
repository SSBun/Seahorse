#if os(macOS)
import SwiftUI
import AppKit

struct MCPSettingsSectionView: View {
    @StateObject private var settings = MCPSettings.shared
    @StateObject private var manager = MCPHelperManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MCP Server")
                .font(.system(size: 13, weight: .semibold))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable MCP Server")
                        .font(.system(size: 13, weight: .medium))
                    Text("Allow local agents to search, create, and update Seahorse bookmarks.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .disabled(settings.status == .restarting)
                    .onChange(of: settings.isEnabled) { _, isEnabled in
                        if isEnabled {
                            manager.start()
                        } else {
                            manager.stop()
                        }
                    }
            }

            HStack(spacing: 8) {
                Text("Status")
                    .font(.system(size: 12, weight: .medium))
                Text(settings.status.rawValue)
                    .font(.system(size: 12))
                    .foregroundStyle(statusColor)
            }

            valueRow(label: "URL", value: settings.mcpURL) {
                copy(settings.mcpURL)
            }

            valueRow(label: "Token", value: settings.externalToken) {
                copy(settings.externalToken)
            }

            HStack(spacing: 8) {
                Button("Copy Header") {
                    copy("Authorization: Bearer \(settings.externalToken)")
                }

                Button("Regenerate Token") {
                    settings.regenerateExternalToken()
                    manager.restart()
                }

                Button("Force Restart", systemImage: "arrow.clockwise") {
                    Task {
                        await manager.forceRestart()
                    }
                }
                .disabled(!settings.isEnabled || settings.status == .restarting)
            }

            Text("First version is local-only, bookmark-only, and does not expose delete tools.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch settings.status {
        case .running:
            .green
        case .restarting:
            .orange
        case .failed, .portUnavailable:
            .red
        case .stopped:
            .secondary
        }
    }

    private func valueRow(label: String, value: String, copyAction: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

            Button("Copy", action: copyAction)
        }
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
#endif
