import ShadesCore

/// Drops a picture onto the video as a sticker: on a free upper track, sized and placed, with the
/// die-cut look, a motion preset and an optional sound when it appears. One undo step.
public struct AddSticker: ToolCommand {

  // MARK: Lifecycle

  public init(
    mediaID: Media.ID,
    at time: MediaTime,
    duration: MediaTime? = nil,
    x: Double? = nil,
    y: Double? = nil,
    scale: Double? = nil,
    rotation: Double? = nil,
    look: StickerLook? = nil,
    motion: MotionPreset? = nil,
    soundID: Media.ID? = nil,
  ) {
    self.mediaID = mediaID
    at = time
    self.duration = duration
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
    self.look = look
    self.motion = motion
    self.soundID = soundID
  }

  // MARK: Public

  public static let title = "Add Sticker"
  public static let name = "add_sticker"
  public static let summary = "Drop an imported picture (best a PNG with a see-through background) "
    + "onto the video as a sticker: on a free track above, with a white die-cut border and shadow, "
    + "a motion preset (default pop) and an optional sound when it appears. Import pictures and "
    + "sounds with import_media first; animate groups afterwards with apply_motion."
  public static let parameters = JSONSchema.object(
    [
      "media_id": Fields.mediaID,
      "at": Fields.time("When it appears"),
      "duration": JSONSchema.number("How long it stays, in seconds (default 3)", minimum: 0.04),
      "x": JSONSchema.number("Horizontal offset as a fraction of the frame width; 0 is centered"),
      "y": JSONSchema.number("Vertical offset as a fraction of the frame height; positive is down"),
      "scale": JSONSchema.number("Size; 1 fits the frame (default 0.35)", minimum: 0.01),
      "rotation": JSONSchema.number("Clockwise rotation in degrees (default -4, a slight tilt)"),
      "look": JSONSchema.object([
        "border": JSONSchema.number("White border as a fraction of the picture, 0 for none"),
        "shadow": JSONSchema.boolean("A soft drop shadow"),
        "paper": JSONSchema.boolean("A printed-paper grain over the sticker (default false)"),
      ]),
      "motion": JSONSchema.string(
        "How it comes on (default pop)",
        values: MotionPreset.allCases.map(\.rawValue),
      ),
      "sound_id": JSONSchema.string("Imported sound to play as it appears, from import_media"),
    ],
    required: ["media_id", "at"],
  )

  public let mediaID: Media.ID
  public let at: MediaTime
  public let duration: MediaTime?
  public let x: Double?
  public let y: Double?
  public let scale: Double?
  public let rotation: Double?
  public let look: StickerLook?
  public let motion: MotionPreset?
  public let soundID: Media.ID?

  public func apply(to project: inout Project) throws(CommandError) {
    let media = try project.requireMedia(mediaID)
    guard media.hasVideo else {
      throw rejected(.invalidValue("a sticker needs a picture, not a sound"))
    }
    let start = project.onFrame(at)
    let range = try project.sourceRange(
      of: media,
      from: .zero,
      to: duration ?? MediaTime(seconds: 3),
    )
    let clipID = project.placeOnTop(media, range: range, at: start)
    try SetClip(
      clipID: clipID,
      x: x ?? 0,
      y: y ?? 0,
      scale: scale ?? 0.35,
      rotation: rotation ?? -4,
    ).apply(to: &project)
    let location = try project.requireClip(clipID)
    project.timeline.tracks[location.track].clips[location.clip].sticker = look ?? StickerLook()
    try ApplyMotion(clipIDs: [clipID], preset: motion ?? .pop).apply(to: &project)
    if let soundID {
      let sound = try project.requireMedia(soundID)
      guard sound.hasAudio, !sound.hasVideo else {
        throw rejected(.invalidValue("the sticker's sound must be a sound-only file"))
      }
      project.placeOnTop(
        sound,
        range: try project.sourceRange(of: sound, from: nil, to: nil),
        at: start,
      )
    }
  }

}
