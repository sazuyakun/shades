import ShadesCommands
import ShadesMCP
import SwiftUI

/// A short-lived pill announcing Claude's latest edit, so changes never happen unnoticed, with
/// Undo for the whole request it belongs to.
struct ClaudeToast: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    Group {
      if let entry = server.activity.recentEntry {
        HStack(spacing: 8) {
          Circle()
            .fill(entry.isError ? Theme.negative : Theme.claude)
            .frame(width: 6, height: 6)
          Text(verbatim: "Claude · \(entry.title)")
            .font(.callout)
          if let request = server.activity.request(containing: entry), request.hasChanges {
            Button("Undo") { undo(request) }
              .buttonStyle(CapsuleButtonStyle())
              .help("Take back everything Claude changed for \"\(request.title)\"")
          }
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
  @Environment(Editor.self) private var editor

  private func undo(_ request: ClaudeRequest) {
    do {
      try server.activity.undo(request.id, in: editor)
    } catch {
      onError(error.errorDescription ?? "Claude's request couldn't be undone.")
    }
  }

}
