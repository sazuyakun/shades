import ShadesCore

/// Mutes or hides a track. Fields left out stay as they are.
public struct SetTrack: ToolCommand {

  // MARK: Lifecycle

  public init(track: String, muted: Bool? = nil, hidden: Bool? = nil) {
    self.track = track
    self.muted = muted
    self.hidden = hidden
  }

  // MARK: Public

  public static let title = "Change Track"
  public static let name = "set_track"
  public static let summary = "Mute a track's sound or hide its pictures."
  public static let parameters = JSONSchema.object(
    [
      "track": Fields.track,
      "muted": JSONSchema.boolean("Silence the track"),
      "hidden": JSONSchema.boolean("Hide the track's pictures"),
    ],
    required: ["track"],
  )

  public let track: String
  public let muted: Bool?
  public let hidden: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let index = try project.requireTrack(track)
    project.timeline.tracks[index].isMuted = muted ?? project.timeline.tracks[index].isMuted
    project.timeline.tracks[index].isHidden = hidden ?? project.timeline.tracks[index].isHidden
  }

}
