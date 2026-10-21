import Foundation
import ShadesCore

// MARK: - LoudnessProfile

/// A mix measured in 5 ms slices: each slice's K-weighted energy and true peak. The loudness at
/// any master level and limiter, and the limiter itself, come from it without reading the mix
/// again.
public struct LoudnessProfile: Sendable {

  // MARK: Public

  /// The loudness the mix would have at `gain`, with `envelope` (one gain per slice) limiting it.
  public func loudness(gain: Double = 1, envelope: [Double]? = nil) -> Loudness {
    let level = { (slice: Int) in gain * (envelope?[slice] ?? 1) }
    let peak = peaks.indices.lazy.map { peaks[$0] * level($0) }.max() ?? 0
    // why: like the standard's meter, only whole 100 ms steps make blocks.
    let steps = (samples / Self.sliceLength) / Self.slicesPerStep
    let stepEnergies = (0 ..< steps).map { step in
      (step * Self.slicesPerStep ..< (step + 1) * Self.slicesPerStep).reduce(0.0) { total, slice in
        total + energies[slice] * level(slice) * level(slice)
      }
    }
    let blockLength = Double(Self.sliceLength * Self.slicesPerStep * Self.stepsPerBlock)
    // why: a block is four steps, so blocks overlap by 75% as the standard asks.
    let blocks = stepEnergies.indices.dropFirst(Self.stepsPerBlock - 1).map { step in
      stepEnergies[step + 1 - Self.stepsPerBlock ... step].reduce(0, +) / blockLength
    }
    let loud = blocks.filter { Self.lufs($0) > -70 }
    guard !loud.isEmpty else {
      return Loudness(integrated: -.infinity, peak: Self.decibels(peak))
    }
    let threshold = Self.lufs(loud.reduce(0, +) / Double(loud.count)) - 10
    let gated = loud.filter { Self.lufs($0) > threshold }
    return Loudness(
      integrated: Self.lufs(gated.reduce(0, +) / Double(max(gated.count, 1))),
      peak: Self.decibels(peak),
    )
  }

  /// The master level and limiter that make the mix play at `target` LUFS with true peaks at or
  /// under `ceiling` dBTP, or `nil` when the mix is silent. The level stays within 0 to 8.
  public func normalized(to target: Double, ceiling: Double = -1) -> Normalization? {
    let before = loudness()
    guard before.integrated.isFinite else {
      return nil
    }
    var gain = min(pow(10, (target - before.integrated) / 20), Self.loudest)
    var envelope = limiting(at: gain, ceiling: ceiling - Self.margin)
    // why: limiting takes a little loudness away, so the level creeps up until it lands.
    for _ in 0 ..< 12 {
      let reached = loudness(gain: gain, envelope: envelope).integrated
      let next = min(gain * pow(10, (target - reached) / 20), Self.loudest)
      guard abs(target - reached) > 0.05, next != gain else {
        break
      }
      gain = next
      envelope = limiting(at: gain, ceiling: ceiling - Self.margin)
    }
    return Normalization(
      gain: gain,
      limiter: points(of: envelope),
      before: before,
      after: loudness(gain: gain, envelope: envelope),
    )
  }

  // MARK: Internal

  /// Samples in a slice: 5 ms at 48 kHz.
  static let sliceLength = 240

  /// Each slice's K-weighted energy: the sum of both channels' squared samples.
  let energies: [Double]
  /// Each slice's true peak, as a linear level.
  let peaks: [Double]
  /// How many samples were measured (the last slice may be short).
  let samples: Int

  /// The limiter's gain for each slice at master `gain`: low enough that no slice's peak goes
  /// over `ceiling` dBTP, falling over 10 ms before a peak and recovering over 200 ms after.
  func limiting(at gain: Double, ceiling: Double) -> [Double] {
    let most = pow(10, ceiling / 20)
    var envelope = peaks.map { min(1, most / max(gain * $0, 1e-12)) }
    for slice in envelope.indices.dropLast().reversed() {
      envelope[slice] = min(envelope[slice], envelope[slice + 1] + Self.attackStep)
    }
    for slice in envelope.indices.dropFirst() {
      envelope[slice] = min(envelope[slice], envelope[slice - 1] + Self.releaseStep)
    }
    return envelope
  }

  /// `envelope` as gain points on slice edges, without the points a straight line already
  /// passes through. Each edge takes the lower of its two slices' gains, so the line between
  /// edges never rises above either slice's own. Empty when nothing is limited.
  func points(of envelope: [Double]) -> [GainPoint] {
    guard envelope.contains(where: { $0 < 1 }) else {
      return []
    }
    let edges = (0 ... envelope.count).map { edge in
      (
        time: Double(edge * Self.sliceLength) / Self.sampleRate,
        gain: min(envelope[max(edge - 1, 0)], envelope[min(edge, envelope.count - 1)]),
      )
    }
    var kept = [edges[0]]
    for index in edges.indices.dropFirst().dropLast() {
      guard let last = kept.last else {
        continue
      }
      let next = edges[index + 1]
      let share = (edges[index].time - last.time) / (next.time - last.time)
      if abs(last.gain + (next.gain - last.gain) * share - edges[index].gain) > 1e-6 {
        kept.append(edges[index])
      }
    }
    if let last = edges.last {
      kept.append(last)
    }
    return kept.map { edge in
      GainPoint(
        time: MediaTime(value: Int64((edge.time * Self.sampleRate).rounded()), timescale: 48000),
        gain: edge.gain,
      )
    }
  }

  // MARK: Private

  private static let sampleRate = 48000.0
  /// 100 ms of slices: the standard's step.
  private static let slicesPerStep = 20
  private static let stepsPerBlock = 4
  /// How far under the ceiling the limiter aims (dB), so peaks never land on it.
  private static let margin = 0.1
  /// The highest master level normalising sets (about +18 dB).
  private static let loudest = 8.0
  /// How far the limiter's gain moves per slice: falling fully in two slices, rising in 40.
  private static let attackStep = 0.5
  private static let releaseStep = 0.025

  private static func lufs(_ meanSquare: Double) -> Double {
    -0.691 + 10 * log10(max(meanSquare, 1e-12))
  }

  private static func decibels(_ level: Double) -> Double {
    20 * log10(max(level, 1e-9))
  }

}

// MARK: - Normalization

/// A mix's master level and limiter for a loudness target, with the loudness before and after.
public struct Normalization: Sendable {
  /// The master level to set (1 unchanged).
  public let gain: Double
  /// The limiter's gain over the timeline.
  public let limiter: [GainPoint]
  /// The mix as it is at a master level of 1, unlimited.
  public let before: Loudness
  /// The mix at `gain` through `limiter`.
  public let after: Loudness
}
