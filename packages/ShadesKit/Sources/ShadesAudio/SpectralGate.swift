import Accelerate
import Foundation

/// Gates noise frame by frame: each Hann-windowed frame's frequencies near the noise level are
/// turned down by a soft mask, smoothed across neighbouring frequencies and over time (opening
/// fast, closing slowly), never below a floor. At 75% overlap, overlap-adding the results
/// rebuilds the input exactly when nothing is gated. Ported from Nebula.
final class SpectralGate {

  // MARK: Lifecycle

  /// A gate for audio at `sampleRate`; `strength` 0 to 1 gates harder and turns noise down
  /// further (up to 30 dB).
  init?(sampleRate: Double, strength: Double) {
    var size = 256
    while size < min(16384, Int(sampleRate * 0.04)) {
      size *= 2
    }
    guard let fft = RealFFT(size: size) else {
      return nil
    }
    self.fft = fft
    self.size = size
    hop = size / 4
    binCount = size / 2 + 1
    window = (0 ..< size).map { Float(0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(size))) }
    let strength = Float(min(max(strength, 0), 1))
    threshold = 3 + 6 * strength
    floor = powf(10, -30 * strength / 20)
    let hopSeconds = Double(size / 4) / sampleRate
    opening = Float(1 - exp(-hopSeconds / 0.005))
    closing = Float(1 - exp(-hopSeconds / 0.06))
    noise = [Float](repeating: 1e-20, count: binCount)
    previous = [Float](repeating: 0, count: binCount)
  }

  // MARK: Internal

  let size: Int
  let hop: Int
  let binCount: Int

  /// Uses `spectrum` (from `analyse`'s power scale) as the noise to gate.
  func setNoise(_ spectrum: [Float]) {
    guard spectrum.count == binCount else {
      return
    }
    noise = vDSP.add(1e-20, spectrum)
  }

  /// A frame's power spectrum and its level in dBFS.
  func analyse(_ frame: [Float]) -> (power: [Float], levelDB: Float) {
    let (_, _, power) = transform(frame)
    let meanSquare = vDSP.meanSquare(frame)
    return (power, 10 * log10(max(meanSquare, 1e-20)))
  }

  /// The frame with its noise gated, windowed and scaled for overlap-adding at `hop`.
  func process(_ frame: [Float]) -> [Float] {
    var (real, imag, power) = transform(frame)
    let mask = gains(for: power)
    let nyquist = imag[0] * mask[binCount - 1]
    real = vDSP.multiply(real, Array(mask[0 ..< size / 2]))
    imag = vDSP.multiply(imag, Array(mask[0 ..< size / 2]))
    imag[0] = nyquist
    var output = [Float](repeating: 0, count: size)
    fft.inverse(real: &real, imag: &imag, output: &output)
    // why: the round trip scales by 2·size, and Hann windows at 75% overlap add up to 1.5.
    return vDSP.multiply(1 / (2 * Float(size) * 1.5), vDSP.multiply(output, window))
  }

  // MARK: Private

  /// Spreads a bin's gain over its neighbours, weighted 1 2 3 2 1.
  private static let spread: [Float] = [1, 2, 3, 2, 1]

  private let fft: RealFFT
  private let window: [Float]
  private let threshold: Float
  private let floor: Float
  private let opening: Float
  private let closing: Float
  private var noise: [Float]
  private var previous: [Float]

  private func transform(_ frame: [Float]) -> (real: [Float], imag: [Float], power: [Float]) {
    var real = [Float](repeating: 0, count: size / 2)
    var imag = [Float](repeating: 0, count: size / 2)
    var power = [Float](repeating: 0, count: binCount)
    fft.forward(vDSP.multiply(frame, window), real: &real, imag: &imag)
    fft.power(real: real, imag: imag, into: &power)
    return (real, imag, power)
  }

  /// The gain for each bin: a smoothstep from `threshold` to 6 dB above it over the noise,
  /// spread across frequency, smoothed over time, kept above the floor.
  private func gains(for power: [Float]) -> [Float] {
    let ratio = vDSP.divide(vDSP.add(1e-20, power), noise)
    let decibels = ratio.map { 10 * log10($0) }
    let raw = decibels.map { value -> Float in
      let x = min(max((value - threshold) / 6, 0), 1)
      return x * x * (3 - 2 * x)
    }
    let spread = (0 ..< binCount).map { bin -> Float in
      var sum: Float = 0
      var weight: Float = 0
      for (offset, tap) in Self.spread.enumerated()
        where (0 ..< binCount).contains(bin + offset - 2)
      {
        sum += raw[bin + offset - 2] * tap
        weight += tap
      }
      return sum / weight
    }
    previous = zip(spread, previous).map { target, last in
      last + (target - last) * (target > last ? opening : closing)
    }
    return previous.map { floor + (1 - floor) * $0 }
  }

}
