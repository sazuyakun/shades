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

  // MARK: Private

  /// A 1 kHz sine, the same in both channels, interleaved at 48 kHz.
  private func tone(seconds: Double, amplitude: Float) -> [Float] {
    (0 ..< Int(seconds * 48000)).flatMap { index -> [Float] in
      let value = amplitude * Float(sin(2 * Double.pi * 1000 * Double(index) / 48000))
      return [value, value]
    }
  }

}
