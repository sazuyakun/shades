import Accelerate

/// A real FFT of a power-of-two size in vDSP's packed format: after `forward`, `real[0]` is the
/// DC term and `imag[0]` the Nyquist term. A round trip scales the signal by `2 * size`. Ported
/// from Nebula.
final class RealFFT {

  // MARK: Lifecycle

  init?(size: Int) {
    guard size >= 4, size & (size - 1) == 0 else {
      return nil
    }
    let log2n = vDSP_Length(size.trailingZeroBitCount)
    guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
      return nil
    }
    self.size = size
    self.log2n = log2n
    self.setup = setup
  }

  deinit {
    vDSP_destroy_fftsetup(setup)
  }

  // MARK: Internal

  let size: Int

  /// Transforms `input` (`size` samples) into `real` and `imag` (`size / 2` values each).
  func forward(_ input: [Float], real: inout [Float], imag: inout [Float]) {
    let half = size / 2
    input.withUnsafeBufferPointer { source in
      real.withUnsafeMutableBufferPointer { realBuffer in
        imag.withUnsafeMutableBufferPointer { imagBuffer in
          guard
            let samples = source.baseAddress, let realBase = realBuffer.baseAddress,
            let imagBase = imagBuffer.baseAddress
          else {
            return
          }
          var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
          samples.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
          }
          vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
        }
      }
    }
  }

  /// Transforms a packed spectrum back into `output` (`size` samples, unnormalised).
  func inverse(real: inout [Float], imag: inout [Float], output: inout [Float]) {
    let half = size / 2
    real.withUnsafeMutableBufferPointer { realBuffer in
      imag.withUnsafeMutableBufferPointer { imagBuffer in
        output.withUnsafeMutableBufferPointer { destination in
          guard
            let realBase = realBuffer.baseAddress, let imagBase = imagBuffer.baseAddress,
            let samples = destination.baseAddress
          else {
            return
          }
          var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
          vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
          samples.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
            vDSP_ztoc(&split, 1, complex, 2, vDSP_Length(half))
          }
        }
      }
    }
  }

  /// Power per bin (`size / 2 + 1` values, DC to Nyquist) of a packed spectrum.
  func power(real: [Float], imag: [Float], into power: inout [Float]) {
    let half = size / 2
    var realCopy = real
    var imagCopy = imag
    realCopy.withUnsafeMutableBufferPointer { realBuffer in
      imagCopy.withUnsafeMutableBufferPointer { imagBuffer in
        power.withUnsafeMutableBufferPointer { destination in
          guard
            let realBase = realBuffer.baseAddress, let imagBase = imagBuffer.baseAddress,
            let powers = destination.baseAddress
          else {
            return
          }
          var split = DSPSplitComplex(realp: realBase, imagp: imagBase)
          vDSP_zvmags(&split, 1, powers, 1, vDSP_Length(half))
          powers[0] = realBase[0] * realBase[0]
          powers[half] = imagBase[0] * imagBase[0]
        }
      }
    }
  }

  // MARK: Private

  private let log2n: vDSP_Length
  private let setup: FFTSetup

}
