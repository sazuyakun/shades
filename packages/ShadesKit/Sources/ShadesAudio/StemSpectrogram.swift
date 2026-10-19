import Foundation

/// The spectrogram HTDemucs works on, made exactly as Demucs makes it: a 4096-point STFT with a
/// 1024 hop and a Hann window, scaled by 1/√4096, framed so frame `t` covers samples from
/// `t * 1024`, without the Nyquist bin. The model sees it as separate real and imaginary parts.
struct StemSpectrogram {

  // MARK: Lifecycle

  init?() {
    guard let fft = RealFFT(size: Self.size) else {
      return nil
    }
    self.fft = fft
    window = (0 ..< Self.size).map { 0.5 - 0.5 * Float(cos(2 * Double.pi * Double($0) / 4096)) }
  }

  // MARK: Internal

  static let size = 4096
  static let hop = 1024
  static let bins = 2048

  /// How many frames a signal of `length` samples has.
  static func frames(for length: Int) -> Int {
    (length + hop - 1) / hop
  }

  /// The spectrogram of `samples`, as real and imaginary parts laid out bin by bin, each bin
  /// holding every frame.
  func forward(_ samples: [Float]) -> (real: [Float], imag: [Float]) {
    let frames = Self.frames(for: samples.count)
    let padded = Self.reflectPadded(samples, frames: frames)
    var real = [Float](repeating: 0, count: Self.bins * frames)
    var imag = real
    var frameReal = [Float](repeating: 0, count: Self.bins)
    var frameImag = frameReal
    // why: vDSP's forward FFT is twice the DFT, and Demucs normalises by √4096 = 64.
    let scale: Float = 1 / 128
    for frame in 0 ..< frames {
      let start = frame * Self.hop
      let windowed = (0 ..< Self.size).map { padded[start + $0] * window[$0] }
      fft.forward(windowed, real: &frameReal, imag: &frameImag)
      real[frame] = frameReal[0] * scale
      for bin in 1 ..< Self.bins {
        real[bin * frames + frame] = frameReal[bin] * scale
        imag[bin * frames + frame] = frameImag[bin] * scale
      }
    }
    return (real, imag)
  }

  /// The signal of `length` samples a spectrogram laid out like `forward`'s describes.
  func inverse(real: [Float], imag: [Float], length: Int) -> [Float] {
    let frames = Self.frames(for: length)
    let pad = Self.hop / 2 * 3
    var output = [Float](repeating: 0, count: frames * Self.hop + 2 * pad + Self.size)
    var frameReal = [Float](repeating: 0, count: Self.bins)
    var frameImag = frameReal
    var samples = [Float](repeating: 0, count: Self.size)
    // why: vDSP's inverse is 4096× the true inverse; Demucs then multiplies by √4096 = 64. The
    // squared Hann windows at a quarter hop always add up to 1.5.
    let scale: Float = 64 / 4096 / 1.5
    for frame in 0 ..< frames {
      for bin in 0 ..< Self.bins {
        frameReal[bin] = real[bin * frames + frame]
        frameImag[bin] = imag[bin * frames + frame]
      }
      frameImag[0] = 0
      fft.inverse(real: &frameReal, imag: &frameImag, output: &samples)
      let start = frame * Self.hop
      for index in 0 ..< Self.size {
        output[start + index] += samples[index] * window[index] * scale
      }
    }
    return Array(output[pad ..< pad + length])
  }

  // MARK: Private

  private let fft: RealFFT
  private let window: [Float]

  /// `samples` reflected at both ends, by 1536 samples and enough more to fill the last frame.
  private static func reflectPadded(_ samples: [Float], frames: Int) -> [Float] {
    let pad = hop / 2 * 3
    let right = pad + frames * hop - samples.count
    let leading = (0 ..< pad).map { samples[pad - $0] }
    let trailing = (0 ..< right).map { samples[samples.count - 2 - $0] }
    return leading + samples + trailing
  }

}
