import ShadesMCP
import SwiftUI

/// A toolbar pill showing whether Claude can connect. When it can't, clicking it explains why
/// and what to do.
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
      .font(.callout)
    }
    .help(message)
    .popover(isPresented: $isShowingDetails, arrowEdge: .bottom) {
      Text(message)
        .frame(width: 260, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
    }
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server
  @State private var isShowingDetails = false

  private var title: String {
    switch server.status {
    case .starting: "Claude"
    case .ready: "Claude ready"
    case .failed: "Claude offline"
    }
  }

  private var color: Color {
    switch server.status {
    case .starting: .gray
    case .ready: .green
    case .failed: .red
    }
  }

  private var message: String {
    switch server.status {
    case .starting:
      "Getting ready for Claude…"
    case .ready:
      "Claude can connect. Use the shades-mcp relay from Claude Code or Claude Desktop."
    case .failed(let error):
      error.errorDescription ?? "Claude can't connect."
    }
  }

}
