import Accelerate

/// Estimates a recording's noise spectrum from its quietest frames in one pass: frames are
/// sorted into 1 dB loudness buckets, and the profile is the mean spectrum of the quietest
/// buckets holding about a tenth of the frames. Digital silence is ignored. Ported from Nebula.
struct NoiseProfile {

  // MARK: Lifecycle

  init(binCount: Int, quietFraction: Double = 0.1) {
    self.binCount = binCount
    self.quietFraction = quietFraction
    sums = Array(repeating: [], count: Self.bucketCount)
    counts = Array(repeating: 0, count: Self.bucketCount)
  }

  // MARK: Internal

  /// Adds one frame's power spectrum and its level in dBFS.
  mutating func add(power: [Float], levelDB: Float) {
    guard levelDB.isFinite, levelDB > Self.lowestDB else {
      return
    }
    let bucket = min(Self.bucketCount - 1, max(0, Int(levelDB - Self.lowestDB)))
    if sums[bucket].isEmpty {
      sums[bucket] = [Double](repeating: 0, count: binCount)
    }
    for bin in 0 ..< binCount {
      sums[bucket][bin] += Double(power[bin])
    }
    counts[bucket] += 1
  }

  /// The mean power spectrum of the quietest frames, or `nil` when none was usable.
  func spectrum() -> [Float]? {
    let total = counts.reduce(0, +)
    guard total > 0 else {
      return nil
    }
    let target = max(1, Int((Double(total) * quietFraction).rounded()))
    var accumulated = [Double](repeating: 0, count: binCount)
    var used = 0
    for bucket in 0 ..< Self.bucketCount where counts[bucket] > 0 {
      for bin in 0 ..< binCount {
        accumulated[bin] += sums[bucket][bin]
      }
      used += counts[bucket]
      if used >= target {
        break
      }
    }
    return accumulated.map { Float($0 / Double(used)) }
  }

  // MARK: Private

  private static let lowestDB: Float = -100
  private static let bucketCount = 100

  private let binCount: Int
  private let quietFraction: Double
  private var sums: [[Double]]
  private var counts: [Int]

}
