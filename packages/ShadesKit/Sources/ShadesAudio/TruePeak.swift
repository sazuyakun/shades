import Accelerate

/// Finds one channel's true peak: the loudest point of the waveform, between samples too, by
/// 4× oversampling with a windowed-sinc filter (ITU-R BS.1770 Annex 2). Encoders and resamplers
/// reconstruct those in-between points, so they're what clips.
struct TruePeak {

  // MARK: Internal

  /// For each of `samples` (continuing the ones before), the loudest of the four oversampled
  /// points it finishes, as a positive level.
  mutating func levels(of samples: [Double]) -> [Double] {
    let signal = history + samples
    var loudest = [Double](repeating: 0, count: samples.count)
    var phase = [Double](repeating: 0, count: samples.count)
    for filter in Self.filters {
      vDSP_convD(
        signal,
        1,
        filter,
        1,
        &phase,
        1,
        vDSP_Length(samples.count),
        vDSP_Length(Self.taps),
      )
      loudest = vDSP.maximum(loudest, vDSP.absolute(phase))
    }
    history = Array(signal.suffix(Self.taps - 1))
    return loudest
  }

  // MARK: Private

  /// Input samples each oversampled point reads.
  private static let taps = 12
  private static let factor = 4

  /// The filter split into one set of coefficients per oversampled point, reversed for
  /// `vDSP_convD` (which slides them forward over the signal). Phase 0 lands on an input sample,
  /// the others between samples; each sums to 1.
  private static let filters: [[Double]] = (0 ..< factor).map { phase in
    let length = Double(taps * factor)
    let coefficients = (0 ..< taps).map { tap in
      let index = Double(tap * factor + phase)
      let offset = (index - length / 2) / Double(factor)
      let sinc = offset == 0 ? 1 : sin(.pi * offset) / (.pi * offset)
      let window = 0.5 - 0.5 * cos(2 * .pi * (index + 0.5) / length)
      return sinc * window
    }
    let total = coefficients.reduce(0, +)
    return coefficients.reversed().map { $0 / total }
  }

  /// The last samples of the previous run, which the next run's first points still read.
  private var history = [Double](repeating: 0, count: taps - 1)

}
