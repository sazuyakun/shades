import ShadesMCP
import SwiftUI

/// Settings › Claude: whether Claude can connect, and how.
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
      LabeledContent("Port") {
        Text(verbatim: "127.0.0.1:\(server.port)")
          .textSelection(.enabled)
      }
      Text(server.status.message)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
    .formStyle(.grouped)
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server

}
