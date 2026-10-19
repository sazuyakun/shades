import Foundation
@testable import ShadesAudio
import ShadesTestSupport
import Testing

struct WaveformTests {

  @Test
  func `peaks follow the sound: full scale is 1, silence is 0, -20 dB is half`() {
    let stretch = 8000 / 25
    let samples = [Float](repeating: 1, count: stretch)
      + [Float](repeating: 0, count: stretch)
      + [Float](repeating: 0.1, count: stretch)
    #expect(Waveform.peaks(of: samples) == [1, 0, 0.5])
  }

  @Test
  func `a file gets 25 peaks a second, loud where it sounds`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 2, bursts: [(0, 1)])
    let peaks = try await Waveform.peaks(in: url)
    #expect(peaks.count == 50)
    #expect(peaks[10] == 0.85)
    #expect(peaks[40] == 0)
  }

}
