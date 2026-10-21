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
      if let media = clip.mediaID.flatMap(media(withID:)), clip.sourceEnd > media.duration {
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

  // MARK: Private

  private func speedKeyframes(of clip: Clip) -> [Keyframe] {
    clip.keyframes.filter { $0.property == .speed }.sorted { $0.time < $1.time }
  }

}
