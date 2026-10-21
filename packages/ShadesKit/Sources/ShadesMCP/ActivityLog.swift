import Foundation
import Observation
import ShadesCommands
import ShadesCore
import ShadesMedia

/// Everything Claude changed over MCP, grouped into requests (newest first) and saved with the
/// project, plus the edit it made a moment ago (toasted, with its clips glowing purple on the
/// timeline, then fading).
@MainActor
@Observable
public final class ActivityLog {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// How long the latest edit stays announced and its clips stay highlighted.
  public static let highlightDuration = Duration.seconds(3)
  /// Claude's calls closer together than this belong to one request, unless Claude starts a
  /// new one with `start_request`.
  public static let requestGap: TimeInterval = 120
  /// Most requests kept; older ones are dropped.
  public static let requestLimit = 200

  /// Claude's requests, newest first.
  public private(set) var requests = [ClaudeRequest]()
  /// The edit Claude just made, until `highlightDuration` passes; the UI toasts it.
  public private(set) var recentEntry: ActivityEntry?
  /// The background jobs each request started while Shades has been open.
  public private(set) var jobs = [ClaudeRequest.ID: [Job.ID]]()
  /// The request a Claude tool call is working on right now, so the background jobs it starts
  /// log their edits under it.
  public internal(set) var runningRequestID: ClaudeRequest.ID?

  /// Clips the recent edit changed, so the timeline can make them glow.
  public var recentlyChangedClipIDs: Set<UUID> {
    recentEntry?.changedClipIDs ?? []
  }

  /// The request a step belongs to.
  public func request(containing entry: ActivityEntry) -> ClaudeRequest? {
    requests.first { $0.steps.contains { $0.id == entry.id } }
  }

  /// Shows the requests saved with the project that just opened.
  public func load(_ requests: [ClaudeRequest]) {
    self.requests = requests
    recentEntry = nil
    jobs = [:]
    runningRequestID = nil
  }

  /// Logs an edit a background job made for request `id`, from `before` to `after`.
  public func record(
    _ title: String,
    summary: String,
    from before: Project,
    to after: Project,
    in id: ClaudeRequest.ID,
  ) {
    record(
      ActivityEntry(title: title, summary: summary, isError: false, from: before, to: after),
      in: id,
    )
  }

  /// Keeps the name of the snapshot saved just before request `id`.
  public func setSnapshot(_ name: String, for id: ClaudeRequest.ID) {
    if let index = requests.firstIndex(where: { $0.id == id }) {
      requests[index].snapshot = name
    }
  }

  /// Takes back everything request `id` changed, as one undo step, keeping later edits. Throws
  /// `editedSince` when later edits changed the same things.
  public func undo(_ id: ClaudeRequest.ID, in editor: Editor) throws(CommandError) {
    guard let request = requests.first(where: { $0.id == id }) else {
      throw .invalidArguments("there's no request \(id) in the History; see get_history")
    }
    try editor.perform(
      [UndoChanges(changes: request.steps.compactMap(\.change))],
      title: "Undo \(request.title)",
    )
  }

  // MARK: Internal

  /// Starts a request named after what the user asked. Returns its ID, and whether it's new
  /// (rather than an empty current one renamed), so a snapshot is due.
  func startRequest(
    named name: String,
    at now: Date = .now,
  ) -> (id: ClaudeRequest.ID, isNew: Bool) {
    if let current = requests.first, current.steps.isEmpty, isOpen(current, at: now) {
      requests[0].name = name
      requests[0].lastActive = now
      return (current.id, false)
    }
    return (begin(ClaudeRequest(name: name, date: now)), true)
  }

  /// The request Claude's next edit belongs to: the current one while Claude keeps working, or a
  /// new one after `requestGap` of quiet. `isNew` says a snapshot is due.
  func requestForEdit(at now: Date = .now) -> (id: ClaudeRequest.ID, isNew: Bool) {
    if let current = requests.first, isOpen(current, at: now) {
      requests[0].lastActive = now
      return (current.id, false)
    }
    return (begin(ClaudeRequest(date: now)), true)
  }

  /// Keeps the current request open while Claude is still working on it (reading, rendering…).
  func touch(at now: Date = .now) {
    if let current = requests.first, isOpen(current, at: now) {
      requests[0].lastActive = now
    }
  }

  /// Adds a step to request `id` and keeps it as the recent edit until `highlightDuration`
  /// passes.
  func record(_ entry: ActivityEntry, in id: ClaudeRequest.ID) {
    guard let index = requests.firstIndex(where: { $0.id == id }) else {
      return
    }
    requests[index].steps.append(entry)
    recentEntry = entry
    Task {
      try? await Task
        .sleep(for: Self.highlightDuration) // why: a cancelled sleep just clears sooner.
      if recentEntry?.id == entry.id {
        recentEntry = nil
      }
    }
  }

  /// Notes background jobs request `id` started.
  func attach(_ jobIDs: [Job.ID], to id: ClaudeRequest.ID) {
    jobs[id, default: []] += jobIDs
  }

  // MARK: Private

  private func isOpen(_ request: ClaudeRequest, at now: Date) -> Bool {
    now.timeIntervalSince(request.lastActive) < Self.requestGap
  }

  /// Adds a new request on top, dropping requests that never changed anything and the oldest
  /// past `requestLimit`. Returns its ID.
  private func begin(_ request: ClaudeRequest) -> ClaudeRequest.ID {
    requests.removeAll { $0.steps.isEmpty && jobs[$0.id] == nil }
    requests.insert(request, at: 0)
    if requests.count > Self.requestLimit {
      requests.removeLast()
    }
    return request.id
  }

}
