import ShadesCore

extension Timeline {
  /// The clip that ends exactly where `clip` starts on its track: the other side of a cut a
  /// transition can go on.
  func clip(cuttingInto clip: Clip) -> Clip? {
    location(ofClip: clip.id).flatMap { location in
      tracks[location.track].clips.first { $0.timelineEnd == clip.timelineStart }
    }
  }
}
