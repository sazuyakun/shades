import ShadesCore

/// Takes back earlier edits (all of a Claude request's) while keeping everything changed since:
/// clips they added go, clips they removed come back, values they changed return. It fails when
/// a later edit changed the same things, since taking them back would undo that edit too.
public struct UndoChanges: Command {

  // MARK: Lifecycle

  public init(changes: [ProjectChange]) {
    self.changes = changes
  }

  // MARK: Public

  public static let title = "Undo Request"

  /// The edits' changes, oldest first.
  public let changes: [ProjectChange]

  public func apply(to project: inout Project) throws(CommandError) {
    var json: JSONValue? = project.savedJSON
    for change in changes.reversed() {
      json = try change.reverted(json)
    }
    guard let json else {
      throw rejected(.editedSince)
    }
    var restored = try Project(savedJSON: json)
    for index in restored.timeline.tracks.indices {
      restored.timeline.tracks[index].clips.sort { $0.timelineStart < $1.timelineStart }
      let clips = restored.timeline.tracks[index].clips
      guard zip(clips, clips.dropFirst()).allSatisfy({ $0.timelineEnd <= $1.timelineStart }) else {
        throw rejected(.editedSince)
      }
    }
    let media = Set(restored.media.map(\.id))
    guard restored.timeline.allClips.allSatisfy({ $0.mediaID.map(media.contains) ?? true }) else {
      throw rejected(.editedSince)
    }
    guard restored != project else {
      throw rejected(.nothingToUndo)
    }
    project = restored
  }

}
