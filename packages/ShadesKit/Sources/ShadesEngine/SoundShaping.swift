import ShadesCore

/// What a track's sound gets on top of its volume: the master limiter's gain over the timeline
/// and the track's pan. `TrackTap` applies it as sound plays and exports; `MixReader` applies it
/// to the samples it reads, so measuring hears exactly what plays.
struct SoundShaping: Sendable {

  // MARK: Lifecycle

  /// Shaping by the `limiter`'s points and a `pan` from −1 (left) to 1 (right).
  init(limiter: [GainPoint], pan: Double) {
    times = limiter.map(\.time.seconds)
    gains = limiter.map(\.gain)
    // why: a balance control: the far side fades out and the near side stays as recorded.
    left = Float(min(1, 1 - pan))
    right = Float(min(1, 1 + pan))
  }

  // MARK: Internal

  /// The left channel's gain from the pan.
  let left: Float
  /// The right channel's gain from the pan.
  let right: Float

  /// Whether the limiter turns anything down.
  var isLimiting: Bool {
    !times.isEmpty
  }

  /// The limiter's gain at `time` (seconds on the timeline): straight lines between its points,
  /// holding the end ones.
  func limiterGain(at time: Double) -> Float {
    guard let first = times.first, let last = times.last, time > first else {
      return Float(gains.first ?? 1)
    }
    guard time < last else {
      return Float(gains[gains.count - 1])
    }
    var low = 0
    var high = times.count - 1
    while high - low > 1 {
      let middle = (low + high) / 2
      if times[middle] <= time {
        low = middle
      } else {
        high = middle
      }
    }
    let share = (time - times[low]) / (times[high] - times[low])
    return Float(gains[low] + (gains[high] - gains[low]) * share)
  }

  // MARK: Private

  /// The limiter's points, in seconds and linear gain.
  private let times: [Double]
  private let gains: [Double]

}
