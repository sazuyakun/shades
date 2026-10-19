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
    tiltX: Double? = nil,
    tiltY: Double? = nil,
    depth: Double? = nil,
    opacity: Double? = nil,
    depthSlot: DepthSlot? = nil,
    volume: Double? = nil,
    audioEnabled: Bool? = nil,
    sticker: StickerLook? = nil,
    fadeIn: MediaTime? = nil,
    fadeOut: MediaTime? = nil,
  ) {
    self.clipID = clipID
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
    self.tiltX = tiltX
    self.tiltY = tiltY
    self.depth = depth
    self.opacity = opacity
    self.depthSlot = depthSlot
    self.volume = volume
    self.audioEnabled = audioEnabled
    self.sticker = sticker
    self.fadeIn = fadeIn
    self.fadeOut = fadeOut
  }

  // MARK: Public

  public static let title = "Change Clip"
  public static let name = "set_clip"
  public static let summary = "Change a clip's position, size, rotation, 3D tilt and depth, "
    + "opacity, depth slot, volume or sound fades. Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "x": JSONSchema.number("Horizontal offset as a fraction of the frame width; 0 is centered"),
      "y": JSONSchema.number("Vertical offset as a fraction of the frame height; positive is down"),
      "scale": JSONSchema.number("Size; 1 fits the frame", minimum: 0.01, maximum: 20),
      "rotation": JSONSchema.number("Clockwise rotation in degrees"),
      "tilt_x": JSONSchema.number(
        "Tilt back in degrees with perspective (the top leans away); negative leans forward",
        minimum: -89,
        maximum: 89,
      ),
      "tilt_y": JSONSchema.number(
        "Turn to the side in degrees with perspective (the right edge leans away)",
        minimum: -89,
        maximum: 89,
      ),
      "depth": JSONSchema.number(
        "Distance towards the viewer as a fraction of the frame height, with perspective; "
          + "negative is further away (default 0)",
        minimum: -10,
        maximum: 1.5,
      ),
      "opacity": JSONSchema.number("0 is invisible, 1 is solid", minimum: 0, maximum: 1),
      "depth_slot": JSONSchema.string(
        "Where the layer sits relative to the person cut out of the clips below it",
        values: DepthSlot.allCases.map(\.rawValue),
      ),
      "volume": JSONSchema.number(
        "0 is silent, 1 unchanged, 2 twice as loud",
        minimum: 0,
        maximum: 4,
      ),
      "audio_enabled": JSONSchema.boolean("Whether a video clip plays its own sound"),
      "fade_in": JSONSchema.number("Seconds the sound takes to rise from silence", minimum: 0),
      "fade_out": JSONSchema.number("Seconds the sound takes to fall to silence", minimum: 0),
      "sticker": JSONSchema.object([
        "border": JSONSchema.number(
          "White die-cut border as a fraction of the picture; with shadow false and border 0 "
            + "the sticker look is removed"
        ),
        "shadow": JSONSchema.boolean("A soft drop shadow"),
      ]),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let x: Double?
  public let y: Double?
  public let scale: Double?
  public let rotation: Double?
  public let tiltX: Double?
  public let tiltY: Double?
  public let depth: Double?
  public let opacity: Double?
  public let depthSlot: DepthSlot?
  public let volume: Double?
  public let audioEnabled: Bool?
  public let sticker: StickerLook?
  public let fadeIn: MediaTime?
  public let fadeOut: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    if let opacity, !(0 ... 1).contains(opacity) {
      throw rejected(.invalidValue("opacity goes from 0 to 1"))
    }
    if let scale, !(0.01 ... 20).contains(scale) {
      throw rejected(.invalidValue("scale goes from 0.01 to 20"))
    }
    if [tiltX, tiltY].contains(where: { $0.map { !(-89 ... 89).contains($0) } ?? false }) {
      throw rejected(.invalidValue("tilt goes from -89 to 89 degrees"))
    }
    if let depth, !(-10 ... 1.5).contains(depth) {
      throw rejected(.invalidValue("depth goes from -10 (far away) to 1.5 (close)"))
    }
    if let sticker, !(0 ... 0.3).contains(sticker.border) {
      throw rejected(.invalidValue("a sticker border goes from 0 to 0.3 of the picture"))
    }
    if let volume, !(0 ... 4).contains(volume) {
      throw rejected(.invalidValue("volume goes from 0 to 4"))
    }
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    if
      let fade = [fadeIn, fadeOut].compactMap(\.self)
        .first(where: { $0 > clip.duration || $0 < .zero })
    {
      throw rejected(.invalidRange("a fade of \(fade.seconds) s doesn't fit the clip"))
    }
    clip.fadeIn = fadeIn.map(project.onFrame) ?? clip.fadeIn
    clip.fadeOut = fadeOut.map(project.onFrame) ?? clip.fadeOut
    clip.transform.x = x ?? clip.transform.x
    clip.transform.y = y ?? clip.transform.y
    clip.transform.scale = scale ?? clip.transform.scale
    clip.transform.rotation = rotation ?? clip.transform.rotation
    clip.transform.tiltX = tiltX ?? clip.transform.tiltX
    clip.transform.tiltY = tiltY ?? clip.transform.tiltY
    clip.transform.depth = depth ?? clip.transform.depth
    clip.opacity = opacity ?? clip.opacity
    clip.depth = depthSlot ?? clip.depth
    clip.volume = volume ?? clip.volume
    clip.isAudioEnabled = audioEnabled ?? clip.isAudioEnabled
    if let sticker {
      clip.sticker = sticker.border == 0 && !sticker.shadow ? nil : sticker
    }
    project.timeline.tracks[location.track].clips[location.clip] = clip
  }

}
