import Foundation
@testable import ShadesAudio
import Testing

struct StemSpectrogramTests {

  @Test
  func `a signal comes back unchanged through the spectrogram, away from its ends`() throws {
    let spectrogram = try #require(StemSpectrogram())
    let samples = (0 ..< 20000).map { index in
      Float(sin(Double(index) * 0.031) * 0.4 + sin(Double(index) * 0.7) * 0.1)
    }
    let (real, imag) = spectrogram.forward(samples)
    let back = spectrogram.inverse(real: real, imag: imag, length: samples.count)
    // why: Demucs drops the frames reaching past each end, so the outer 4096 samples come back
    // faded; overlapping segments cover them.
    let middle = 4096 ..< samples.count - 4096
    let error = middle.lazy.map { abs(samples[$0] - back[$0]) }.max() ?? 1
    #expect(error < 1e-4)
  }

  @Test
  func `steady sound lands in the first bin at Demucs' scale`() throws {
    let spectrogram = try #require(StemSpectrogram())
    let (real, _) = spectrogram.forward([Float](repeating: 1, count: 8192))
    // why: a Hann window sums to 2048, and Demucs divides by √4096 = 64.
    #expect(abs(real[3] - 32) < 1e-3)
  }

}
