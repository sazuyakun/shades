import Foundation
import ShadesAudio
import Testing

struct NoiseReducerTests {

  // MARK: Internal

  @Test
  func `strength 0 leaves the sound alone and length always matches`() async {
    let input = noisyTone()
    let same = await NoiseReducer.reduce(input, sampleRate: 48000, strength: 0)
    #expect(same == input)
    let cleaned = await NoiseReducer.reduce(input, sampleRate: 48000, strength: 0.8)
    #expect(cleaned.count == input.count)
  }

  @Test
  func `noise between words drops while the voice stays`() async {
    let input = noisyTone()
    let cleaned = await NoiseReducer.reduce(input, sampleRate: 48000, strength: 0.8)
    let gap = 48000 * 3 ..< 48000 * 4
    let tone = 48000 / 2 ..< 48000 * 3 / 2
    #expect(rms(cleaned[gap]) < rms(input[gap]) * 0.3, "the noise-only gap is much quieter")
    #expect(rms(cleaned[tone]) > rms(input[tone]) * 0.8, "the tone is kept")
  }

  // MARK: Private

  /// A 440 Hz tone for 2 s, then 3 s of noise alone; noise throughout.
  private func noisyTone() -> [Float] {
    var seed: UInt64 = 42
    return (0 ..< 48000 * 5).map { index in
      seed = seed &* 6_364_136_223_846_793_005 &+ 1
      let noise = Float(Int64(bitPattern: seed >> 11) % 1000) / 1000 * 0.02
      let tone = index < 48000 * 2 ? 0.3 * Float(sin(2 * .pi * 440 * Double(index) / 48000)) : 0
      return tone + noise
    }
  }

  private func rms(_ samples: ArraySlice<Float>) -> Float {
    (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
  }

}
