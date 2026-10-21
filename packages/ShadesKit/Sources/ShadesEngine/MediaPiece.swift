import AVFoundation
import ShadesCore

// MARK: - MediaPiece

/// A stretch of a clip's media played at one steady rate: `source` of the media, stretched or
/// squeezed to last `duration` from `at` on the timeline.
struct MediaPiece {

  // MARK: Internal

  let source: CMTimeRange
  let at: CMTime
  let duration: CMTime

  /// The pieces `clip` plays its media in: one at a steady speed; one per frame along a speed
  /// ramp, each starting on the source moment `Clip.sourceTime` gives, so playback lands on the
  /// same frames as everything else that reads it; and on a freeze frame, a sliver of its frame
  /// stretched over the whole clip.
  static func pieces(of clip: Clip, frame: MediaTime) -> [MediaPiece] {
    if clip.isFrozen {
      return [MediaPiece(
        source: CMTimeRange(start: clip.sourceStart.cmTime, duration: sliver),
        at: clip.timelineStart.cmTime,
        duration: clip.duration.cmTime,
      )]
    }
    guard clip.hasSpeedRamp else {
      return [MediaPiece(
        from: clip.sourceStart,
        to: clip.sourceEnd,
        over: clip.timelineStart,
        clip.timelineEnd,
      )]
    }
    var edges = [clip.timelineStart]
    while let last = edges.last, last < clip.timelineEnd {
      edges.append(min(last + frame, clip.timelineEnd))
    }
    let sources = edges.map(clip.sourceTime(at:))
    return zip(zip(edges, edges.dropFirst()), zip(sources, sources.dropFirst()))
      .map { timeline, source in
        MediaPiece(from: source.0, to: source.1, over: timeline.0, timeline.1)
      }
  }

  /// The piece with any media after `end` cut off, its length cut to match; `nil` when none of
  /// it comes before `end`.
  func ending(by end: CMTime) -> MediaPiece? {
    guard source.end > end else {
      return self
    }
    guard source.start < end else {
      return nil
    }
    let kept = CMTimeRange(start: source.start, end: end)
    let fraction = kept.duration.seconds / source.duration.seconds
    return MediaPiece(
      source: kept,
      at: at,
      duration: CMTime(seconds: duration.seconds * fraction, preferredTimescale: 60000),
    )
  }

  /// Puts the piece of `track` into `target`: inserted, then stretched to its length.
  func insert(from track: AVAssetTrack, into target: AVMutableCompositionTrack) throws {
    try target.insertTimeRange(source, of: track, at: at)
    if source.duration != duration {
      target.scaleTimeRange(CMTimeRange(start: at, duration: source.duration), toDuration: duration)
    }
  }

  // MARK: Private

  /// How much of a frozen frame's media is stretched: short enough to hold one frame.
  private static let sliver = CMTime(value: 1, timescale: 600)

}

extension MediaPiece {
  /// The source from `start` to `end` played over the timeline from `at` to `until`.
  fileprivate init(
    from start: MediaTime,
    to end: MediaTime,
    over at: MediaTime,
    _ until: MediaTime,
  ) {
    source = CMTimeRange(start: start.cmTime, end: end.cmTime)
    self.at = at.cmTime
    duration = (until - at).cmTime
  }
}
