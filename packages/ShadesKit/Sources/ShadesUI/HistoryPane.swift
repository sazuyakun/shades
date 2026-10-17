import ShadesCommands
import ShadesEngine
import ShadesMCP
import SwiftUI

/// Every change Claude made over MCP, newest first: a read-only edit log, not a chat.
struct HistoryPane: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "History", detail: "\(server.activity.entries.count)")
      if server.activity.entries.isEmpty {
        Text("Changes Claude makes over MCP appear here.")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(.horizontal, 14)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(server.activity.entries) { entry in
              HistoryRow(entry: entry, onShow: { show(entry) })
              Hairline()
            }
          }
        }
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server
  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

  /// Moves the playhead to the earliest clip the entry changed.
  private func show(_ entry: ActivityEntry) {
    let starts = editor.project.timeline.tracks
      .flatMap(\.clips)
      .filter { entry.changedClipIDs.contains($0.id) }
      .map(\.timelineStart.seconds)
    guard let start = starts.min() else {
      return
    }
    Task { await player.seek(toSeconds: start) }
  }

}
