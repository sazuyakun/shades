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
    bend: Double? = nil,
    opacity: Double? = nil,
    depthSlot: DepthSlot? = nil,
    volume: Double? = nil,
    audioEnabled: Bool? = nil,
    sticker: StickerLook? = nil,
    fadeIn: MediaTime? = nil,
    fadeOut: MediaTime? = nil,
    cleanSound: Bool? = nil,
    motionBlur: Double? = nil,
    footageBlur: Bool? = nil,
    speed: Double? = nil,
    crop: Crop? = nil,
    cutoutEdge: CutoutEdge? = nil,
  ) {
    self.clipID = clipID
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
    self.tiltX = tiltX
    self.tiltY = tiltY
    self.depth = depth
    self.bend = bend
    self.opacity = opacity
    self.depthSlot = depthSlot
    self.volume = volume
    self.audioEnabled = audioEnabled
    self.sticker = sticker
    self.fadeIn = fadeIn
    self.fadeOut = fadeOut
    self.cleanSound = cleanSound
    self.motionBlur = motionBlur
    self.footageBlur = footageBlur
    self.speed = speed
    self.crop = crop
    self.cutoutEdge = cutoutEdge
  }

  // MARK: Public

  public static let title = "Change Clip"
  public static let name = "set_clip"
  public static let summary = "Change a clip's position, size, rotation, 3D tilt, depth and "
    + "bend, crop, opacity, depth slot, cut-out edge, motion blur, volume, sound fades or "
    + "speed. Leave out what shouldn't change."
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
      "bend": JSONSchema.number(
        "Curve the layer around an upright axis, in degrees of arc across its width: positive "
          + "bends its sides away (a label round a bottle), negative towards the viewer (a "
          + "curved screen)",
        minimum: -360,
        maximum: 360,
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
      "motion_blur": JSONSchema.number(
        "How long the clip blurs as it moves, as a share of the timeline's shutter: 1 follows "
          + "the timeline (default), 0 none, 2 twice as long",
        minimum: 0,
        maximum: 4,
      ),
      "footage_blur": JSONSchema.boolean(
        "Also blur movement inside the footage (a pan, a running subject) along its optical "
          + "flow. Turning it on queues the flow analysis; the blur shows once that finishes"
      ),
      "fade_in": JSONSchema.number("Seconds the sound takes to rise from silence", minimum: 0),
      "fade_out": JSONSchema.number("Seconds the sound takes to fall to silence", minimum: 0),
      "clean_sound": JSONSchema.boolean(
        "Play the noise-reduced sound (made by reduce_noise) instead of the original"
      ),
      "speed": JSONSchema.number(
        "How fast a video or sound clip plays: 0.5 is half speed, 2 twice as fast. It keeps its "
          + "first and last frames, so it gets longer or shorter and later clips on its track "
          + "move with its end. Sound is stretched with its pitch kept, and muted below 0.25 or "
          + "above 4. Speed keyframes (set_keyframes) ramp it instead",
        minimum: Clip.speeds.lowerBound,
        maximum: Clip.speeds.upperBound,
      ),
      "crop": JSONSchema.object([
        "left": JSONSchema.number("Fraction of the picture's width cut off the left", minimum: 0),
        "right": JSONSchema.number("Fraction of the width cut off the right", minimum: 0),
        "top": JSONSchema.number("Fraction of the picture's height cut off the top", minimum: 0),
        "bottom": JSONSchema.number("Fraction of the height cut off the bottom", minimum: 0),
      ]),
      "cutout_edge": JSONSchema.object([
        "feather": JSONSchema.number(
          "How wide the cut-out's edge fades, as a fraction of the picture's width",
          minimum: 0,
          maximum: 0.1,
        ),
        "choke": JSONSchema.number(
          "Pulls the cut-out's edge in (positive) or pushes it out (negative), as a fraction of "
            + "the picture's width",
          minimum: -0.05,
          maximum: 0.05,
        ),
        "smoothing": JSONSchema.number(
          "Rounds off a jagged cut-out edge and fills small holes",
          minimum: 0,
          maximum: 1,
        ),
      ]),
      "sticker": JSONSchema.object([
        "border": JSONSchema.number(
          "White die-cut border as a fraction of the picture; with border 0 and shadow and "
            + "paper false the sticker look is removed"
        ),
        "shadow": JSONSchema.boolean("A soft drop shadow"),
        "paper": JSONSchema.boolean("A printed-paper grain over the sticker"),
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
  public let bend: Double?
  public let opacity: Double?
  public let depthSlot: DepthSlot?
  public let volume: Double?
  public let audioEnabled: Bool?
  public let sticker: StickerLook?
  public let fadeIn: MediaTime?
  public let fadeOut: MediaTime?
  public let cleanSound: Bool?
  public let motionBlur: Double?
  public let footageBlur: Bool?
  public let speed: Double?
  /// Replaces the whole crop; edges left out are uncut.
  public let crop: Crop?
  /// Replaces how the cut-out's edge is refined; fields left out are untouched (0).
  public let cutoutEdge: CutoutEdge?

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
    if let bend, !(-360 ... 360).contains(bend) {
      throw rejected(.invalidValue("bend goes from -360 to 360 degrees"))
    }
    if let sticker, !(0 ... 0.3).contains(sticker.border) {
      throw rejected(.invalidValue("a sticker border goes from 0 to 0.3 of the picture"))
    }
    if let volume, !(0 ... 4).contains(volume) {
      throw rejected(.invalidValue("volume goes from 0 to 4"))
    }
    if let motionBlur, !(0 ... 4).contains(motionBlur) {
      throw rejected(.invalidValue("motion blur goes from 0 (none) to 4 times the shutter"))
    }
    if let crop {
      let edges = [crop.left, crop.right, crop.top, crop.bottom]
      guard
        edges.allSatisfy({ $0 >= 0 }), crop.left + crop.right < 1, crop.top + crop.bottom < 1
      else {
        throw rejected(.invalidValue(
          "crop edges are fractions from 0, and opposite edges must leave some picture"
        ))
      }
    }
    if let cutoutEdge {
      guard
        (0 ... 0.1).contains(cutoutEdge.feather), (-0.05 ... 0.05).contains(cutoutEdge.choke),
        (0 ... 1).contains(cutoutEdge.smoothing)
      else {
        throw rejected(.invalidValue(
          "a cut-out edge's feather goes from 0 to 0.1, its choke from -0.05 to 0.05 and its "
            + "smoothing from 0 to 1"
        ))
      }
    }
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    if let speed {
      try project.requireSpeedChangeable(clip)
      guard Clip.speeds.contains(speed) else {
        throw rejected(.invalidValue(
          "speed goes from \(Clip.speeds.lowerBound) to \(Clip.speeds.upperBound); "
            + "freeze_frame holds a frame"
        ))
      }
      clip.speed = speed
    }
    if
      let fade = [fadeIn, fadeOut].compactMap(\.self)
        .first(where: { $0 > clip.duration || $0 < .zero })
    {
      throw rejected(.invalidRange("a fade of \(fade.seconds) s doesn't fit the clip"))
    }
    if
      footageBlur == true,
      clip.mediaID.flatMap(project.media(withID:)).map({ !$0.hasVideo || $0.isStill }) ?? true
    {
      throw rejected(
        .invalidValue("footage blur needs a video clip; still layers blur as they move")
      )
    }
    clip.fadeIn = fadeIn.map(project.onFrame) ?? clip.fadeIn
    clip.fadeOut = fadeOut.map(project.onFrame) ?? clip.fadeOut
    clip.cleanSound = cleanSound ?? clip.cleanSound
    clip.transform.x = x ?? clip.transform.x
    clip.transform.y = y ?? clip.transform.y
    clip.transform.scale = scale ?? clip.transform.scale
    clip.transform.rotation = rotation ?? clip.transform.rotation
    clip.transform.tiltX = tiltX ?? clip.transform.tiltX
    clip.transform.tiltY = tiltY ?? clip.transform.tiltY
    clip.transform.depth = depth ?? clip.transform.depth
    clip.transform.bend = bend ?? clip.transform.bend
    clip.opacity = opacity ?? clip.opacity
    clip.depth = depthSlot ?? clip.depth
    clip.volume = volume ?? clip.volume
    clip.isAudioEnabled = audioEnabled ?? clip.isAudioEnabled
    clip.motionBlur = motionBlur ?? clip.motionBlur
    clip.footageBlur = footageBlur ?? clip.footageBlur
    clip.crop = crop ?? clip.crop
    clip.cutoutEdge = cutoutEdge ?? clip.cutoutEdge
    if let sticker {
      clip.sticker = sticker.border == 0 && !sticker.shadow && !sticker.paper ? nil : sticker
    }
    try project.replaceClip(at: location, with: clip)
  }

}
