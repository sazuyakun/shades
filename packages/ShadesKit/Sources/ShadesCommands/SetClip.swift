import ShadesCore

/// Changes how a clip is drawn and heard. Fields left out stay as they are.
public struct SetClip: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    x: Double? = nil,
    y: Double? = nil,
    scale: Double? = nil,
    rotation: Double? = nil,
    opacity: Double? = nil,
    depth: DepthSlot? = nil,
    volume: Double? = nil,
    audioEnabled: Bool? = nil,
  ) {
    self.clipID = clipID
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
    self.opacity = opacity
    self.depth = depth
    self.volume = volume
    self.audioEnabled = audioEnabled
  }

  // MARK: Public

  public static let title = "Change Clip"
  public static let name = "set_clip"
  public static let summary = "Change a clip's position, size, rotation, opacity, depth slot or "
    + "volume. Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "x": JSONSchema.number("Horizontal offset as a fraction of the frame width; 0 is centered"),
      "y": JSONSchema.number("Vertical offset as a fraction of the frame height; positive is down"),
      "scale": JSONSchema.number("Size; 1 fits the frame", minimum: 0.01, maximum: 20),
      "rotation": JSONSchema.number("Clockwise rotation in degrees"),
      "opacity": JSONSchema.number("0 is invisible, 1 is solid", minimum: 0, maximum: 1),
      "depth": JSONSchema.string(
        "Where the layer sits relative to the person cut out of the clips below it",
        values: DepthSlot.allCases.map(\.rawValue),
      ),
      "volume": JSONSchema.number(
        "0 is silent, 1 unchanged, 2 twice as loud",
        minimum: 0,
        maximum: 4,
      ),
      "audio_enabled": JSONSchema.boolean("Whether a video clip plays its own sound"),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let x: Double?
  public let y: Double?
  public let scale: Double?
  public let rotation: Double?
  public let opacity: Double?
  public let depth: DepthSlot?
  public let volume: Double?
  public let audioEnabled: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    if let opacity, !(0 ... 1).contains(opacity) {
      throw rejected(.invalidValue("opacity goes from 0 to 1"))
    }
    if let scale, !(0.01 ... 20).contains(scale) {
      throw rejected(.invalidValue("scale goes from 0.01 to 20"))
    }
    if let volume, !(0 ... 4).contains(volume) {
      throw rejected(.invalidValue("volume goes from 0 to 4"))
    }
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    clip.transform.x = x ?? clip.transform.x
    clip.transform.y = y ?? clip.transform.y
    clip.transform.scale = scale ?? clip.transform.scale
    clip.transform.rotation = rotation ?? clip.transform.rotation
    clip.opacity = opacity ?? clip.opacity
    clip.depth = depth ?? clip.depth
    clip.volume = volume ?? clip.volume
    clip.isAudioEnabled = audioEnabled ?? clip.isAudioEnabled
    project.timeline.tracks[location.track].clips[location.clip] = clip
  }

}
