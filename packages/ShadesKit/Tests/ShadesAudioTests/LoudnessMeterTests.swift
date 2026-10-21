import Foundation
@testable import ShadesAudio
import Testing

struct LoudnessMeterTests {

  // MARK: Internal

  @Test
  func `a 1 kHz tone at -20 dBFS in both channels reads about -20 LUFS`() {
    var meter = LoudnessMeter.Meter()
    meter.add(tone(seconds: 3, amplitude: 0.1))
    let result = meter.result()
    #expect(abs(result.integrated - -20) < 0.3)
    #expect(abs(result.peak - -20) < 0.1)
  }

  @Test
  func `silence is gated out and alone reads as nothing`() {
    var meter = LoudnessMeter.Meter()
    meter.add(tone(seconds: 2, amplitude: 0.1))
    meter.add([Float](repeating: 0, count: 48000 * 2 * 6))
    // why: blocks overlapping the tone's end carry part of it and pass the gates, as specified.
    #expect(abs(meter.result().integrated - -20) < 0.5)
    var silent = LoudnessMeter.Meter()
    silent.add([Float](repeating: 0, count: 48000 * 2))
    #expect(silent.result().integrated == -.infinity)
  }

  @Test
  func `a tone whose crests fall between samples reads its true peak, not its loudest sample`() {
    // why: a 12 kHz sine shifted by an eighth of a turn is sampled only at 71% of its crest.
    let samples = (0 ..< 48000).flatMap { index -> [Float] in
      let value = 0.5 * Float(sin(2 * Double.pi * 12000 * Double(index) / 48000 + .pi / 4))
      return [value, value]
    }
    let loudestSample = 20 * log10(Double(samples.map(abs).max() ?? 0))
    var meter = LoudnessMeter.Meter()
    meter.add(samples)
    let peak = meter.result().peak
    #expect(abs(loudestSample - -9.03) < 0.1)
    #expect(abs(peak - -6.02) < 0.3)
  }

  @Test
  func `normalising loud peaks reaches the target, limiting the peaks under the ceiling`() throws {
    // why: quiet speech-like tone with sharp loud clicks, like sound effects piling up.
    let samples = (0 ..< 48000 * 6).flatMap { index -> [Float] in
      let time = Double(index) / 48000
      let click = time.truncatingRemainder(dividingBy: 0.5) < 0.004 ? 0.9 : 0
      let value = Float(0.05 * sin(2 * Double.pi * 300 * time) + click * sin(2 * .pi * 2000 * time))
      return [value, value]
    }
    var meter = LoudnessMeter.Meter()
    meter.add(samples)
    let profile = meter.profile()
    let normalization = try #require(profile.normalized(to: -14))
    // why: peaks this far over the loudness can't fit -14 LUFS under -1 dBTP without limiting.
    #expect(normalization.before.peak - normalization.before.integrated > 13)
    #expect(abs(normalization.after.integrated - -14) < 0.1)
    #expect(normalization.after.peak <= -1)
    #expect(!normalization.limiter.isEmpty)
    #expect(normalization.limiter.allSatisfy { (0 ... 1).contains($0.gain) })
  }

  @Test
  func `a mix with room under the ceiling needs no limiter`() throws {
    var meter = LoudnessMeter.Meter()
    meter.add(tone(seconds: 3, amplitude: 0.1))
    let normalization = try #require(meter.profile().normalized(to: -14))
    #expect(abs(normalization.gain - 2) < 0.05)
    #expect(normalization.limiter.isEmpty)
  }

  // MARK: Private

  /// A 1 kHz sine, the same in both channels, interleaved at 48 kHz.
  private func tone(seconds: Double, amplitude: Float) -> [Float] {
    (0 ..< Int(seconds * 48000)).flatMap { index -> [Float] in
      let value = amplitude * Float(sin(2 * Double.pi * 1000 * Double(index) / 48000))
      return [value, value]
    }
  }

}
