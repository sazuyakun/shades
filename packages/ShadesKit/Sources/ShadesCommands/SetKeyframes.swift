import ShadesCore

/// Animates a clip: sets the value one of its properties has at given moments, replacing any
/// keyframe already at that moment.
public struct SetKeyframes: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, keyframes: [Key]) {
    self.clipID = clipID
    self.keyframes = keyframes
  }

  // MARK: Public

  /// One keyframe as Claude gives it: a timeline time rather than a source time.
  public struct Key: Codable, Sendable {
    public init(property: AnimatedProperty, at time: MediaTime, value: Double, easing: Easing?) {
      self.property = property
      at = time
      self.value = value
      self.easing = easing
    }

    public let property: AnimatedProperty
    public let at: MediaTime
    public let value: Double
    public let easing: Easing?
  }

  public static let title = "Set Keyframes"
  public static let name = "set_keyframes"
  public static let summary = "Animate a clip's x, y, scale, rotation, tiltX, tiltY, depth, "
    + "opacity, volume or speed: give the value at moments inside the clip, and the property "
    + "moves between them. A keyframe's easing shapes the move to the next one (spring and "
    + "bouncy overshoot). An animated property ignores its fixed value from set_clip. Each "
    + "keyframe sticks to the frame showing at its moment. Speed keyframes ramp a video or sound "
    + "clip's speed (0.1 to 10): it keeps its first and last frames, so it gets longer or "
    + "shorter and later clips on its track move with its end."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "keyframes": JSONSchema.array(
        "The values to set",
        items: JSONSchema.object(
          [
            "property": JSONSchema.string(
              "What to animate, in set_clip's units",
              values: AnimatedProperty.allCases.map(\.rawValue),
            ),
            "at": Fields.time("When, within the clip"),
            "value": JSONSchema.number("The value at that moment"),
            "easing": JSONSchema.string(
              "How it moves on to the next keyframe. Default linear",
              values: Easing.allCases.map(\.rawValue),
            ),
          ],
          required: ["property", "at", "value"],
        ),
      ),
    ],
    required: ["clip_id", "keyframes"],
  )

  public let clipID: Clip.ID
  public let keyframes: [Key]

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let original = project.timeline.tracks[location.track].clips[location.clip]
    var clip = original
    guard !keyframes.isEmpty else {
      throw rejected(.invalidValue("give at least one keyframe"))
    }
    guard !original.isFrozen else {
      throw rejected(.invalidValue(
        "a freeze frame shows one moment, so it can't be animated; move the camera over it "
          + "with set_camera"
      ))
    }
    for key in keyframes {
      try validate(key.value, for: key.property)
      if key.property == .speed {
        try project.requireSpeedChangeable(original)
      }
      let time = project.onFrame(key.at)
      guard original.timelineStart <= time, time <= original.timelineEnd else {
        throw rejected(.invalidRange(
          "keyframe times must fall within the clip, \(original.timelineStart.seconds)–"
            + "\(original.timelineEnd.seconds) s"
        ))
      }
      // why: every `at` is read against the clip as it was, before a speed keyframe retimes it.
      let keyframe = Keyframe(
        property: key.property,
        time: original.sourceTime(at: time),
        value: key.value,
        easing: key.easing ?? .linear,
      )
      clip.keyframes.removeAll { $0.property == keyframe.property && $0.time == keyframe.time }
      clip.keyframes.append(keyframe)
    }
    clip.keyframes.sort { $0.time < $1.time }
    try project.replaceClip(at: location, with: clip)
  }

  // MARK: Private

  private func validate(_ value: Double, for property: AnimatedProperty) throws(CommandError) {
    switch property {
    case .opacity where !(0 ... 1).contains(value):
      throw rejected(.invalidValue("opacity goes from 0 to 1"))

    case .scale where !(0.01 ... 20).contains(value):
      throw rejected(.invalidValue("scale goes from 0.01 to 20"))

    case .tiltX where !(-89 ... 89).contains(value),
         .tiltY where !(-89 ... 89).contains(value):
      throw rejected(.invalidValue("tilt goes from -89 to 89 degrees"))

    case .volume where !(0 ... 4).contains(value):
      throw rejected(.invalidValue("volume goes from 0 to 4"))

    case .depth where !(-10 ... 1.5).contains(value):
      throw rejected(.invalidValue("depth goes from -10 (far away) to 1.5 (close)"))

    case .speed where !Clip.speeds.contains(value):
      throw rejected(.invalidValue(
        "speed goes from \(Clip.speeds.lowerBound) to \(Clip.speeds.upperBound)"
      ))

    default:
      return
    }
  }

}
