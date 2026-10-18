import Accelerate
import Foundation
import ShadesCore
import ShadesMedia

/// Finds the beats in music: an onset-strength curve (spectral flux), a tempo from its
/// autocorrelation (60–180 BPM), then the grid phase that lands on the strongest onsets.
public enum BeatDetector {

  // MARK: Public

  /// The beat grid of the file at `url`, in its own time.
  @concurrent
  public static func detect(in url: URL) async throws(AudioError) -> BeatGrid {
    let samples: [Float]
    do {
      samples = try await AudioDecoder.mono(from: url, sampleRate: sampleRate)
    } catch {
      throw .unreadable(error)
    }
    return detect(samples: samples)
  }

  // MARK: Internal

  /// The beat grid of mono samples at 22.05 kHz. Pure; empty when there's no steady pulse.
  static func detect(samples: [Float]) -> BeatGrid {
    let onsets = onsetStrength(samples)
    guard onsets.count > Int(4 / hopDuration), let period = beatPeriod(onsets) else {
      return BeatGrid(beatsPerMinute: 0, beats: [])
    }
    let phase = bestPhase(onsets, period: period)
    let beats = stride(from: phase, to: Double(onsets.count), by: period).map { position in
      MediaTime(seconds: snapped(position, in: onsets) * hopDuration, timescale: 1000)
    }
    return BeatGrid(beatsPerMinute: 60 / (period * hopDuration), beats: beats)
  }

  // MARK: Private

  private static let sampleRate = 22_050.0
  /// How strongly the beat must repeat, relative to the onset curve's energy, to count.
  private static let minimumPulseStrength: Float = 0.2
  private static let frameSize = 1024
  private static let hop = 256

  private static var hopDuration: Double {
    Double(hop) / sampleRate
  }

  /// How much louder each frame's spectrum got than the last (rises only), one per hop.
  private static func onsetStrength(_ samples: [Float]) -> [Float] {
    let half = frameSize / 2
    guard
      samples.count > frameSize,
      let fft = vDSP.FFT(
        log2n: vDSP_Length(log2(Double(frameSize))),
        radix: .radix2,
        ofType: DSPSplitComplex.self,
      )
    else {
      return []
    }
    let window = vDSP.window(
      ofType: Float.self,
      usingSequence: .hanningDenormalized,
      count: frameSize,
      isHalfWindow: false,
    )
    let real = UnsafeMutablePointer<Float>.allocate(capacity: half)
    let imaginary = UnsafeMutablePointer<Float>.allocate(capacity: half)
    defer {
      real.deallocate()
      imaginary.deallocate()
    }
    var split = DSPSplitComplex(realp: real, imagp: imaginary)
    var magnitudes = [Float](repeating: 0, count: half)
    var previous = [Float](repeating: 0, count: half)
    var strengths = [Float]()
    for start in stride(from: 0, to: samples.count - frameSize, by: hop) {
      let frame = vDSP.multiply(samples[start ..< start + frameSize], window)
      frame.withUnsafeBufferPointer { buffer in
        guard let base = buffer.baseAddress else {
          return
        }
        base.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
          vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
        }
      }
      fft.forward(input: split, output: &split)
      vDSP.absolute(split, result: &magnitudes)
      let logs = magnitudes.map { log1p($0) }
      strengths.append(zip(logs, previous).reduce(0) { $0 + max($1.0 - $1.1, 0) })
      previous = logs
    }
    let mean = vDSP.mean(strengths)
    return strengths.map { max($0 - mean, 0) }
  }

  /// The beat length in hops (fractional): among lags between 60 and 180 BPM whose average
  /// autocorrelation is near the best, the one closest to 120 BPM, refined between hops.
  private static func beatPeriod(_ onsets: [Float]) -> Double? {
    let shortest = Int((60 / 180) / hopDuration)
    let longest = Int((60 / 60) / hopDuration)
    let scores = (shortest - 1 ... longest + 1).map { lag in correlation(onsets, lag: lag) }
    let energy = correlation(onsets, lag: 0)
    // why: without a pulse that stands out against the onset curve's own energy, there are no
    // beats; steady tones and noise would otherwise get a made-up tempo.
    guard let best = scores.max(), energy > 0, best / energy >= minimumPulseStrength else {
      return nil
    }
    let candidates = (1 ..< scores.count - 1).filter { index in
      scores[index] >= 0.8 * best && scores[index] >= scores[index - 1] && scores[index] >=
        scores[index + 1]
    }
    let preferred = 60 / 120 / hopDuration
    guard
      let index = candidates
        .min(by: {
          abs(Double($0 + shortest - 1) - preferred) < abs(Double($1 + shortest - 1) - preferred)
        })
    else {
      return nil
    }
    let left = scores[index - 1]
    let center = scores[index]
    let right = scores[index + 1]
    let curvature = left - 2 * center + right
    let shift = curvature == 0 ? 0 : Double(0.5 * (left - right) / curvature)
    return Double(index + shortest - 1) + min(max(shift, -0.5), 0.5)
  }

  /// The average product of the onset curve with itself shifted by `lag` hops.
  private static func correlation(_ onsets: [Float], lag: Int) -> Float {
    let count = onsets.count - lag
    guard count > 0 else {
      return 0
    }
    return zip(onsets, onsets.dropFirst(lag)).reduce(Float(0)) { $0 + $1.0 * $1.1 } / Float(count)
  }

  /// The grid offset (in hops) whose beats land on the most onset strength.
  private static func bestPhase(_ onsets: [Float], period: Double) -> Double {
    let candidates = stride(from: 0.0, to: period, by: 1.0)
    return candidates.max { score(onsets, period: period, phase: $0) < score(
      onsets,
      period: period,
      phase: $1,
    ) } ?? 0
  }

  private static func score(_ onsets: [Float], period: Double, phase: Double) -> Float {
    stride(from: phase, to: Double(onsets.count), by: period).reduce(0) { total, position in
      total + onsets[min(Int(position.rounded()), onsets.count - 1)]
    }
  }

  /// A grid position moved onto the strongest onset within two hops, so beats sit on hits.
  private static func snapped(_ position: Double, in onsets: [Float]) -> Double {
    let center = Int(position.rounded())
    let nearby = max(center - 2, 0) ... min(center + 2, onsets.count - 1)
    guard let strongest = nearby.max(by: { onsets[$0] < onsets[$1] }), onsets[strongest] > 0 else {
      return position
    }
    return Double(strongest)
  }

}
