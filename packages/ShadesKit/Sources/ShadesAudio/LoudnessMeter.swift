import Accelerate
import Foundation

// MARK: - LoudnessMeter

/// Measures loudness the way streaming platforms do (ITU-R BS.1770 / EBU R128): K-weighted,
/// in 400 ms blocks, gated to ignore silence and quiet passages, with true peaks.
public enum LoudnessMeter {

  // MARK: Public

  /// The integrated loudness and true peak of stereo audio at 48 kHz, read as interleaved
  /// left/right chunks from `next` until it returns `nil`.
  @concurrent
  public static func measure<Failure: Error>(
    next: @Sendable () async throws(Failure) -> [Float]?
  ) async throws(Failure) -> Loudness {
    try await profile(next: next).loudness()
  }

  /// The same audio measured slice by slice, for working out a level and limiter.
  @concurrent
  public static func profile<Failure: Error>(
    next: @Sendable () async throws(Failure) -> [Float]?
  ) async throws(Failure) -> LoudnessProfile {
    var meter = Meter()
    while let chunk = try await next() {
      meter.add(chunk)
    }
    return meter.profile()
  }

  // MARK: Internal

  /// The measurement in progress: each channel's filters and peak finder, and the slices
  /// measured so far (the last one may still be filling).
  struct Meter {

    // MARK: Internal

    mutating func add(_ interleaved: [Float]) {
      let frames = interleaved.count / 2
      guard frames > 0 else {
        return
      }
      let samples = vDSP.floatToDouble(interleaved)
      let left = stride(from: 0, to: frames * 2, by: 2).map { samples[$0] }
      let right = stride(from: 1, to: frames * 2, by: 2).map { samples[$0] }
      let energy = vDSP.add(
        vDSP.square(leftWeighting.process(left)),
        vDSP.square(rightWeighting.process(right)),
      )
      let peak = vDSP.maximum(leftPeak.levels(of: left), rightPeak.levels(of: right))
      var start = 0
      while start < frames {
        let end = min(start + LoudnessProfile.sliceLength - filled, frames)
        sliceEnergy += vDSP.sum(energy[start ..< end])
        slicePeak = max(slicePeak, vDSP.maximum(peak[start ..< end]))
        filled += end - start
        if filled == LoudnessProfile.sliceLength {
          endSlice()
        }
        start = end
      }
    }

    func profile() -> LoudnessProfile {
      var meter = self
      if meter.filled > 0 {
        meter.endSlice()
      }
      return LoudnessProfile(energies: meter.energies, peaks: meter.peaks, samples: meter.samples)
    }

    func result() -> Loudness {
      profile().loudness()
    }

    // MARK: Private

    private var leftWeighting = KWeighting()
    private var rightWeighting = KWeighting()
    private var leftPeak = TruePeak()
    private var rightPeak = TruePeak()
    private var sliceEnergy = 0.0
    private var slicePeak = 0.0
    private var filled = 0
    private var samples = 0
    private var energies = [Double]()
    private var peaks = [Double]()

    private mutating func endSlice() {
      energies.append(sliceEnergy)
      peaks.append(slicePeak)
      samples += filled
      sliceEnergy = 0
      slicePeak = 0
      filled = 0
    }

  }

}

// MARK: - Loudness

/// How loud a mix is.
public struct Loudness: Sendable {
  /// Integrated loudness in LUFS (YouTube plays at about −14, Instagram about −14 to −16).
  public let integrated: Double
  /// The true peak (the loudest point of the waveform, between samples too) in dBTP; 0 is the
  /// most a file can hold.
  public let peak: Double
}

// MARK: - KWeighting

/// The BS.1770 K-weighting filter at 48 kHz: a high shelf (the head's effect) then a high-pass.
private struct KWeighting {

  // MARK: Internal

  mutating func process(_ samples: [Double]) -> [Double] {
    highPass.process(shelf.process(samples))
  }

  // MARK: Private

  private var shelf = Biquad(
    b: (1.53512485958697, -2.69169618940638, 1.19839281085285),
    a: (-1.69065929318241, 0.73248077421585),
  )
  private var highPass = Biquad(b: (1, -2, 1), a: (-1.99004745483398, 0.99007225036621))

}

// MARK: - Biquad

/// A second-order filter, run over whole runs of samples by `vDSP_deq22D`.
private struct Biquad {

  // MARK: Lifecycle

  /// A filter with feed-forward coefficients `b` and feedback coefficients `a` (a0 is 1).
  init(b: (Double, Double, Double), a: (Double, Double)) {
    coefficients = [b.0, b.1, b.2, a.0, a.1]
  }

  // MARK: Internal

  /// `samples` filtered, continuing from the previous run.
  mutating func process(_ samples: [Double]) -> [Double] {
    let input = inputs + samples
    var output = outputs + [Double](repeating: 0, count: samples.count)
    vDSP_deq22D(input, 1, coefficients, &output, 1, vDSP_Length(samples.count))
    inputs = Array(input.suffix(2))
    outputs = Array(output.suffix(2))
    return Array(output.dropFirst(2))
  }

  // MARK: Private

  private let coefficients: [Double]
  /// The last two samples in and out, which the next run starts from.
  private var inputs = [0.0, 0.0]
  private var outputs = [0.0, 0.0]

}
