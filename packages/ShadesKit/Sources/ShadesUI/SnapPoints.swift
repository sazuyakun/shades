import ShadesCore

/// The times a dragged edge snaps to: the start, the playhead, markers and other clips' edges.
struct SnapPoints {

  // MARK: Lifecycle

  init(timeline: Timeline, playhead: MediaTime, excluding excluded: Set<Clip.ID>) {
    var times: Set = [MediaTime.zero, playhead]
    for clip in timeline.allClips where !excluded.contains(clip.id) {
      times.insert(clip.timelineStart)
      times.insert(clip.timelineEnd)
    }
    times.formUnion(timeline.markers.map(\.time))
    self.times = Array(times)
  }

  // MARK: Internal

  /// Points closer than this snap.
  static let threshold = 8.0

  /// The snap point nearest `time` within the threshold, or `time` itself.
  func snapped(_ time: MediaTime, scale: TimelineScale) -> MediaTime {
    let limit = scale.seconds(atX: Self.threshold)
    let nearest = times.min { abs($0.seconds - time.seconds) < abs($1.seconds - time.seconds) }
    guard let nearest, abs(nearest.seconds - time.seconds) <= limit else {
      return time
    }
    return nearest
  }

  // MARK: Private

  private let times: [MediaTime]

}
