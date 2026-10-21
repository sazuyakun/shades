import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesMedia
import SwiftUI

/// Every request Claude worked on over MCP, newest first, each undoable on its own: a read-only
/// edit log, not a chat.
struct HistoryPane: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(
        title: "History",
        detail: "\(requests.count) Claude request\(requests.count == 1 ? "" : "s")",
      )
      if requests.isEmpty {
        Text("Changes Claude makes over MCP appear here, one row per request.")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(.horizontal, 14)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(requests) { request in
              HistoryRow(
                request: request,
                isLatest: request.id == requests.first?.id,
                jobs: jobs(of: request),
                onUndo: { undo(request) },
                onShow: { show(request) },
                onStop: { stop(request) },
              )
              Hairline()
            }
          }
        }
      }
    }
    .background(Theme.background)
    .alert(
      "This request can't be undone on its own",
      isPresented: Binding(get: { blocked != nil }, set: {
        if !$0 {
          blocked = nil
        }
      }),
      presenting: blocked,
    ) { request in
      if request.snapshot != nil {
        Button("Revert to Before It", role: .destructive) {
          Task { await workspace.revert(before: request) }
        }
      }
      Button("Cancel", role: .cancel) { }
    } message: { request in
      Text(
        "Edits made after \"\(request.title)\" changed the same things, so undoing it alone "
          + "would undo them too. "
          + (request.snapshot == nil
            ? "Pick an earlier version in File › Revert To instead."
            : "You can go back to the snapshot saved just before it; everything after it is "
              + "dropped (⌘Z brings it back).")
      )
    }
  }

  // MARK: Private

  @Environment(MCPServer.self) private var server
  @Environment(Workspace.self) private var workspace
  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  /// The request Undo couldn't take back on its own, while the alert offers a revert.
  @State private var blocked: ClaudeRequest?

  /// Requests that did something or are still working.
  private var requests: [ClaudeRequest] {
    server.activity.requests.filter { !$0.steps.isEmpty || !jobs(of: $0).isEmpty }
  }

  /// The background jobs a request started that are still in the queue.
  private func jobs(of request: ClaudeRequest) -> [Job] {
    let ids = Set(server.activity.jobs[request.id] ?? [])
    return workspace.jobs.jobs.filter { ids.contains($0.id) }
  }

  private func undo(_ request: ClaudeRequest) {
    do {
      try server.activity.undo(request.id, in: editor)
    } catch .editedSince {
      blocked = request
    } catch {
      workspace.errorMessage = error.errorDescription
    }
  }

  /// Selects the request's clips still on the timeline and moves the playhead to the first.
  private func show(_ request: ClaudeRequest) {
    let clips = editor.project.timeline.allClips.filter { request.changedClipIDs.contains($0.id) }
    editor.selection = Set(clips.map(\.id))
    guard let start = clips.map(\.timelineStart.seconds).min() else {
      return
    }
    Task { await player.seek(toSeconds: start) }
  }

  private func stop(_ request: ClaudeRequest) {
    for job in jobs(of: request) where !job.state.isFinished {
      workspace.jobs.cancel(job.id)
    }
  }

}
