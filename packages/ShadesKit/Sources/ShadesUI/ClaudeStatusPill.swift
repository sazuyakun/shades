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
          .fill(color)
          .frame(width: 7, height: 7)
        Text(title)
      }
    }
    .buttonStyle(CapsuleButtonStyle())
    .help(message)
    .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
      Text(message)
        .textSelection(.enabled)
        .frame(width: 280, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
    }
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server
  @State private var isShowingDetails = false

  private var title: String {
    if case .failed = server.status {
      "Claude offline"
    } else {
      "Claude"
    }
  }

  private var color: Color {
    switch server.status {
    case .starting: Theme.faintText
    case .ready: Theme.positive
    case .failed: Theme.negative
    }
  }

  private var message: String {
    switch server.status {
    case .starting:
      "Getting ready for Claude…"

    case .ready:
      "Claude can connect through the shades-mcp relay (apps/mcp). Direct HTTP comes in M2."

    case .failed(let error):
      error.errorDescription ?? "Claude can't connect."
    }
  }

}
