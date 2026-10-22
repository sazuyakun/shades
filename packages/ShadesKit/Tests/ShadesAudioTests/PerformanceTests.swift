import Foundation
import ShadesAudio
import ShadesTestSupport
import Testing

/// Analysis speed gate (see the engine's `PerformanceTests` for how budgets are set and run).
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SHADES_PERFORMANCE"] == "1"))
struct PerformanceTests {

  @Test
  func `analysing 10 minutes of sound takes under a minute`() async throws {
    let url = try AudioFixture.makePulses(periods: 150)
    let clock = ContinuousClock()
    let time = try await clock.measure {
      _ = try await Waveform.peaks(in: url)
      _ = try await SpeechActivity.detect(in: url)
      _ = try await BeatDetector.detect(in: url)
    }
    // why: PLAN §4 only asks that analysis never stutters the editor; this budget keeps a
    // 10-minute project's waveform, speech and beats ready soon after import. Measured 12 s on
    // the M1 dev machine (debug build).
    #expect(time < .seconds(60), "took \(time)")
  }

}
