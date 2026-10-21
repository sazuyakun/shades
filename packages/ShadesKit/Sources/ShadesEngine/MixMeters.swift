import ShadesCore
import Synchronization

// MARK: - MixMeters

/// How loud each track's sound is as it plays, for the mixer's meters. The tracks' taps write
/// it from AVFoundation's audio thread, ahead of the playhead; views read the level at the
/// playhead.
public final class MixMeters: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// The loudest point of `track`'s sound around `time` (seconds on the timeline), after the
  /// limiter and pan but before its volume, or `nil` when none was heard there.
  public func level(of track: Track.ID, at time: Double) -> MeterLevel? {
    readings.withLock { readings in
      readings[track]?.last { $0.start <= time && time < $0.end }?.level
    }
  }

  // MARK: Internal

  /// Notes the loudest point of a buffer of `track`'s sound running from `start` to `end`.
  func record(_ level: MeterLevel, for track: Track.ID, from start: Double, to end: Double) {
    readings.withLock { readings in
      var kept = readings[track] ?? []
      // why: a seek starts the readings again from the new time.
      if let last = kept.last, start < last.start {
        kept.removeAll()
      }
      kept.append(Reading(start: start, end: end, level: level))
      readings[track] = Array(kept.drop { $0.end < start - Self.kept })
    }
  }

  // MARK: Private

  /// How many seconds of readings each track keeps, as playback runs ahead of the playhead.
  private static let kept = 4.0

  private let readings = Mutex<[Track.ID: [Reading]]>([:])

}

// MARK: - MeterLevel

/// A meter's reading: the loudest sample of each channel, as linear levels (1 is full scale).
public struct MeterLevel: Hashable, Sendable {
  public init(left: Double, right: Double) {
    self.left = left
    self.right = right
  }

  public let left: Double
  public let right: Double
}

// MARK: - Reading

/// The level of one buffer of a track's sound, and when it plays.
private struct Reading {
  let start: Double
  let end: Double
  let level: MeterLevel
}
