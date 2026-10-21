import ShadesCore

/// Mutes, solos, levels, pans or hides a track, or sets whether the camera moves it. Fields left
/// out stay as they are.
public struct SetTrack: ToolCommand {

  // MARK: Lifecycle

  public init(
    track: String,
    muted: Bool? = nil,
    hidden: Bool? = nil,
    followsCamera: Bool? = nil,
    volume: Double? = nil,
    pan: Double? = nil,
    soloed: Bool? = nil,
  ) {
    self.track = track
    self.muted = muted
    self.hidden = hidden
    self.followsCamera = followsCamera
    self.volume = volume
    self.pan = pan
    self.soloed = soloed
  }

  // MARK: Public

  public static let title = "Change Track"
  public static let name = "set_track"
  public static let summary = "Mute or solo a track's sound, set its level and pan in the mix, "
    + "hide its pictures, or choose whether the camera (set_camera) moves them. Video tracks "
    + "carry their clips' own sound, so they mute, solo and pan too."
  public static let parameters = JSONSchema.object(
    [
      "track": Fields.track,
      "muted": JSONSchema.boolean("Silence the track"),
      "soloed": JSONSchema.boolean(
        "Play this track alone: while any track is soloed, only soloed tracks are heard"
      ),
      "pan": JSONSchema.number(
        "Where its stereo sound sits: -1 all left, 0 as recorded, 1 all right (mono stays centred)",
        minimum: -1,
        maximum: 1,
      ),
      "hidden": JSONSchema.boolean("Hide the track's pictures"),
      "volume": JSONSchema.number(
        "The track's level in the mix: 0 silent, 1 unchanged, 2 twice as loud",
        minimum: 0,
        maximum: 4,
      ),
      "follows_camera": JSONSchema.boolean(
        "Whether camera moves apply to this track (default: video yes, text no)"
      ),
    ],
    required: ["track"],
  )

  public let track: String
  public let muted: Bool?
  public let hidden: Bool?
  public let followsCamera: Bool?
  public let volume: Double?
  public let pan: Double?
  public let soloed: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let index = try project.requireTrack(track)
    if let volume, !(0 ... 4).contains(volume) {
      throw rejected(.invalidValue("track volume goes from 0 to 4"))
    }
    if let pan, !(-1 ... 1).contains(pan) {
      throw rejected(.invalidValue("pan goes from -1 (left) to 1 (right)"))
    }
    project.timeline.tracks[index].volume = volume ?? project.timeline.tracks[index].volume
    project.timeline.tracks[index].pan = pan ?? project.timeline.tracks[index].pan
    project.timeline.tracks[index].isSoloed = soloed ?? project.timeline.tracks[index].isSoloed
    project.timeline.tracks[index].isMuted = muted ?? project.timeline.tracks[index].isMuted
    project.timeline.tracks[index].isHidden = hidden ?? project.timeline.tracks[index].isHidden
    project.timeline.tracks[index].followsCamera = followsCamera
      ?? project.timeline.tracks[index].followsCamera
  }

}
