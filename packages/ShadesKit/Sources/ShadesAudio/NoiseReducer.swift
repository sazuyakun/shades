import Foundation

/// Takes steady background noise (hiss, hum, fans, traffic rumble) out of a recording by
/// spectral gating, keeping the voice. Ported from Nebula.
public enum NoiseReducer {
  /// `samples` (mono, at `sampleRate`) with their noise gated: `strength` 0 leaves them alone,
  /// 1 gates hardest. Always the same length as the input.
  @concurrent
  public static func reduce(
    _ samples: [Float],
    sampleRate: Double,
    strength: Double,
  ) async -> [Float] {
    guard strength > 0, let gate = SpectralGate(sampleRate: sampleRate, strength: strength) else {
      return samples
    }
    let size = gate.size
    let hop = gate.hop
    var profile = NoiseProfile(binCount: gate.binCount)
    var start = 0
    while start + size <= samples.count {
      let (power, level) = gate.analyse(Array(samples[start ..< start + size]))
      profile.add(power: power, levelDB: level)
      start += hop
    }
    if let spectrum = profile.spectrum() {
      gate.setNoise(spectrum)
    }
    // why: leading zeros give the first samples full overlap; the output is shifted back by them.
    let latency = size - hop
    let padded = [Float](repeating: 0, count: latency) + samples
      + [Float](repeating: 0, count: size + hop)
    var output = [Float](repeating: 0, count: padded.count)
    start = 0
    while start + size <= padded.count {
      let processed = gate.process(Array(padded[start ..< start + size]))
      for index in 0 ..< size {
        output[start + index] += processed[index]
      }
      start += hop
    }
    return Array(output[latency ..< latency + samples.count])
  }
}
