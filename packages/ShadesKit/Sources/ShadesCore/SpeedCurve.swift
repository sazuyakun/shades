import Foundation

// MARK: - SpeedCurve

/// How fast a clip plays through its source: one speed, or speed keyframes (in source time)
/// eased between. It measures the clip's source in timeline seconds: the timeline spends
/// `1 / speed` seconds on each second of source, summed along the curve.
///
/// Between two keyframes the curve is sampled at `samplesPerKeyframe` points and the time per
/// second of source runs straight from one sample to the next, so every length has an exact
/// inverse and longer stretches of source always take longer to play.
struct SpeedCurve {

  // MARK: Lifecycle

  /// The curve of a clip playing at `speed`, or along its `.speed` keyframes when it has any.
  init(speed: Double, keyframes: [Keyframe]) {
    let keys = keyframes.filter { $0.property == .speed }.sorted { $0.time < $1.time }
    guard let first = keys.first, let last = keys.last else {
      pieces = []
      leadWeight = 1 / speed
      trailWeight = 1 / speed
      return
    }
    var pieces = [Piece]()
    var elapsed = 0.0
    for (from, to) in zip(keys, keys.dropFirst()) {
      let start = from.time.seconds
      let length = to.time.seconds - start
      let isSteady = from.easing == .hold || from.value == to.value
      let steps = isSteady ? 1 : Self.samplesPerKeyframe
      for step in 0 ..< steps {
        let piece = Piece(
          start: start + length * Double(step) / Double(steps),
          end: start + length * Double(step + 1) / Double(steps),
          startWeight: 1 / Self.speed(from, to, Double(step) / Double(steps)),
          endWeight: 1 / Self.speed(from, to, isSteady ? 0 : Double(step + 1) / Double(steps)),
          elapsed: elapsed,
        )
        pieces.append(piece)
        elapsed += piece.length
      }
    }
    self.pieces = pieces
    leadWeight = 1 / Self.clamped(first.value)
    trailWeight = 1 / Self.clamped(last.value)
  }

  // MARK: Internal

  /// The timeline seconds from source moment `from` to source moment `to` (negative when `to`
  /// comes first), both in seconds.
  func timelineSeconds(from: Double, to: Double) -> Double {
    position(of: to) - position(of: from)
  }

  /// The source moment, in seconds, the clip reaches `elapsed` timeline seconds after showing
  /// source moment `from` (before it when `elapsed` is negative).
  func sourceSeconds(from: Double, after elapsed: Double) -> Double {
    source(at: position(of: from) + elapsed)
  }

  // MARK: Private

  /// A stretch of source whose timeline seconds per source second (its weight) runs straight
  /// from `startWeight` to `endWeight`. `elapsed` is the timeline seconds from the first piece's
  /// start to this one's.
  private struct Piece {
    let start: Double
    let end: Double
    let startWeight: Double
    let endWeight: Double
    let elapsed: Double

    /// Timeline seconds the whole piece takes.
    var length: Double {
      (startWeight + endWeight) / 2 * (end - start)
    }

    /// Timeline seconds from its start to `offset` source seconds into it.
    func seconds(through offset: Double) -> Double {
      startWeight * offset + (endWeight - startWeight) * offset * offset / (2 * (end - start))
    }

    /// How far into the piece, in source seconds, `seconds` of timeline reaches: the root of
    /// `seconds(through:)`, written so it stays exact when the weight barely changes.
    func offset(reaching seconds: Double) -> Double {
      let slope = (endWeight - startWeight) / (end - start)
      // why: rounding can push the square's argument a hair below zero at the piece's end.
      let root = max(startWeight * startWeight + 2 * slope * seconds, 0).squareRoot()
      return 2 * seconds / (startWeight + root)
    }
  }

  /// Samples per stretch between two eased keyframes: enough that the curve looks smooth.
  private static let samplesPerKeyframe = 64

  private let pieces: [Piece]
  /// Timeline seconds per source second before the first keyframe.
  private let leadWeight: Double
  /// Timeline seconds per source second after the last keyframe.
  private let trailWeight: Double

  /// The speed eased `fraction` of the way from keyframe `from` to `to`, kept to the speeds a
  /// clip can play at (springs overshoot).
  private static func speed(_ from: Keyframe, _ to: Keyframe, _ fraction: Double) -> Double {
    clamped(from.value(towards: to, at: fraction))
  }

  private static func clamped(_ speed: Double) -> Double {
    min(max(speed, Clip.speeds.lowerBound), Clip.speeds.upperBound)
  }

  /// Timeline seconds from the curve's origin (its first keyframe, or source zero without any)
  /// to source moment `source`.
  private func position(of source: Double) -> Double {
    guard let first = pieces.first, let last = pieces.last else {
      return source * leadWeight
    }
    if source < first.start {
      return (source - first.start) * leadWeight
    }
    if source >= last.end {
      return last.elapsed + last.length + (source - last.end) * trailWeight
    }
    let piece = pieces.last { $0.start <= source } ?? first
    return piece.elapsed + piece.seconds(through: source - piece.start)
  }

  /// The source moment `position` timeline seconds from the curve's origin.
  private func source(at position: Double) -> Double {
    guard let first = pieces.first, let last = pieces.last else {
      return position / leadWeight
    }
    if position < 0 {
      return first.start + position / leadWeight
    }
    let total = last.elapsed + last.length
    if position >= total {
      return last.end + (position - total) / trailWeight
    }
    let piece = pieces.last { $0.elapsed <= position } ?? first
    return piece.start + piece.offset(reaching: position - piece.elapsed)
  }

}
