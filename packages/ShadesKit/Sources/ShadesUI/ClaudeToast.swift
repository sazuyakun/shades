import ShadesMCP
import SwiftUI

/// A short-lived pill announcing Claude's latest edit, so changes never happen unnoticed.
struct ClaudeToast: View {

  // MARK: Internal

  var body: some View {
    Group {
      if let entry = server.activity.recentEntry {
        HStack(spacing: 6) {
          Circle()
            .fill(entry.isError ? Theme.negative : Theme.claude)
            .frame(width: 6, height: 6)
          Text(verbatim: "Claude · \(entry.title)")
            .font(.callout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.raised, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.strongHairline) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: 0.2), value: server.activity.recentEntry?.id)
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server

}
