import ShadesCore

/// Adds an empty track above the others of its kind.
public struct AddTrack: ToolCommand {
  public init(kind: TrackKind) {
    self.kind = kind
  }

  public static let title = "Add Track"
  public static let name = "add_track"
  public static let summary = "Add an empty video track (on top of the others), audio track, or "
    + "text track (drawn above the video)."
  public static let parameters = JSONSchema.object(
    ["kind": JSONSchema.string("What the track holds", values: ["video", "audio", "text"])],
    required: ["kind"],
  )

  public let kind: TrackKind

  public func apply(to project: inout Project) throws(CommandError) {
    project.addTrack(kind)
  }
}
