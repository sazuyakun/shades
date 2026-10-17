import ShadesMCP
import SwiftUI

/// Claude's connection as a dot in the title bar. Clicking it explains the state and, when
/// Claude can't connect, what to do.
struct ClaudeStatusPill: View {

  // MARK: Internal

  var body: some View {
    Button {
      isShowingDetails = true
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(server.status.color)
          .frame(width: 7, height: 7)
        Text(server.status.title)
      }
    }
    .buttonStyle(CapsuleButtonStyle())
    .help(server.status.message)
    .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
      Text(server.status.message)
        .textSelection(.enabled)
        .frame(width: 280, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
    }
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server
  @State private var isShowingDetails = false

}
