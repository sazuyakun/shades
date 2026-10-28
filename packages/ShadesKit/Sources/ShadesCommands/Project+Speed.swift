import ShadesCore

/// What every speed change shares: which clips have a speed, and keeping a retimed clip's frames
/// while its length changes.
extension Project {

  // MARK: Internal

  /// Rejects a speed change on a clip that has no speed: text, drawings, adjustments, stills and
  /// freeze frames.
  func requireSpeedChangeable(_ clip: Clip) throws(CommandError) {
    guard let mediaID = clip.mediaID, try !requireMedia(mediaID).isStill else {
      throw rejected(.invalidValue("only video and sound clips have a speed"))
    }
    guard !clip.isFrozen else {
      throw rejected(.invalidValue(
        "a freeze frame holds one moment; trim it to change how long it lasts"
      ))
    }
  }

  /// Puts `clip` in place of the clip at `location`. When its speed changed it keeps the last
  /// frame the old one reached, so it gets longer or shorter and later clips on its track move
  /// with its end.
  mutating func replaceClip(
    at location: (track: Int, clip: Int),
    with clip: Clip,
  ) throws(CommandError) {
    let old = timeline.tracks[location.track].clips[location.clip]
    var clip = clip
    if clip.speed != old.speed || speedKeyframes(of: clip) != speedKeyframes(of: old) {
      let fps = timeline.format.framesPerSecond
      let length = clip.timelineTime(atSource: old.sourceEnd) - clip.timelineStart
      clip.duration = length.roundedToFrame(at: fps)
      if let media = clip.mediaID.flatMap(media(withID:)), clip.sourceEnd > media.length(at: fps) {
        clip.duration = length.flooredToFrame(at: fps)
      }
      guard clip.duration > .zero else {
        throw rejected(.invalidRange("at that speed the clip would be shorter than a frame"))
      }
      timeline.tracks[location.track].shift(
        from: old.timelineEnd,
        by: clip.timelineEnd - old.timelineEnd,
      )
    }
    timeline.tracks[location.track].clips[location.clip] = clip
  }

  /// The steady speed at which `clip` lasts `length` (to the nearest frame) with the same
  /// footage, for `set_clip fit_to`.
  func speed(fitting clip: Clip, to length: MediaTime) throws(CommandError) -> Double {
    try requireSpeedChangeable(clip)
    guard speedKeyframes(of: clip).isEmpty else {
      throw rejected(.invalidValue(
        "fit_to sets one steady speed; remove the clip's speed keyframes first"
      ))
    }
    let target = onFrame(length)
    let speed = (clip.sourceEnd - clip.sourceStart).seconds / target.seconds
    guard target > .zero, Clip.speeds.contains(speed) else {
      throw rejected(.invalidValue(String(
        format: "to last %.3f s the clip would play at %.2f×; speeds go from %.1f to %.0f",
        target.seconds,
        speed,
        Clip.speeds.lowerBound,
        Clip.speeds.upperBound,
      )))
    }
    return speed
  }

  // MARK: Private

  private func speedKeyframes(of clip: Clip) -> [Keyframe] {
    clip.keyframes.filter { $0.property == .speed }.sorted { $0.time < $1.time }
  }

}
