import AppKit
import ShadesMCP
import SwiftUI

/// Settings › Claude: whether Claude can connect, and the one-time command that connects it.
struct ClaudeSettings: View {

  // MARK: Internal

  var body: some View {
    Form {
      LabeledContent("Status") {
        HStack(spacing: 6) {
          Circle()
            .fill(server.status.color)
            .frame(width: 7, height: 7)
          Text(server.status.title)
        }
      }
      LabeledContent("Endpoint") {
        Text(server.endpoint)
          .textSelection(.enabled)
      }
      Section("Connect Claude Code once, from a terminal") {
        HStack {
          Text(server.connectCommand)
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(2)
          Spacer()
          Button("Copy") { copy(server.connectCommand) }
        }
      }
      if case .failed = server.status {
        Text(server.status.message)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .formStyle(.grouped)
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server

  private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

}
