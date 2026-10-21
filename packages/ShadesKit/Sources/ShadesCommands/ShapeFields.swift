import ShadesCore

// MARK: - ShapeFields

/// Argument schemas shared by the tools that place and animate shapes on a clip (masks and grade
/// windows).
enum ShapeFields {
  static let at = Fields.time(
    "Keyframe the position and size given here at this moment inside the clip instead of "
      + "setting the fixed ones; the shape moves between keyframes"
  )
  static let easing = JSONSchema.string(
    "How the shape moves on from this keyframe to the next. Default linear",
    values: Easing.allCases.map(\.rawValue),
  )
  static let clearKeyframes = JSONSchema.boolean(
    "Remove the shape's keyframes first, so it stays where its fixed position puts it"
  )
  static let remove = JSONSchema.boolean("Remove the shape")
}

extension Project {
  /// The source moment of `clip` that shows at timeline time `at`, for a shape keyframe.
  func shapeKeyframeTime(at time: MediaTime, in clip: Clip) throws(CommandError) -> MediaTime {
    let moment = onFrame(time)
    guard clip.timelineStart <= moment, moment <= clip.timelineEnd else {
      throw rejected(.invalidRange(
        "keyframe times must fall within the clip, \(clip.timelineStart.seconds)–"
          + "\(clip.timelineEnd.seconds) s"
      ))
    }
    guard !clip.isFrozen else {
      throw rejected(.invalidValue("a freeze frame shows one moment, so it can't be animated"))
    }
    return clip.sourceTime(at: moment)
  }
}
