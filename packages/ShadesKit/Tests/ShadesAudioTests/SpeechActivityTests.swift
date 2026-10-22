import ShadesAudio
import ShadesCore
import ShadesTestSupport
import Testing

struct SpeechActivityTests {
  @Test
  func `sound between silences is found as speech`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 6, bursts: [(1, 2), (3.5, 4.5)])
    let ranges = try await SpeechActivity.detect(in: url).ranges
    #expect(ranges.count == 2)
    #expect(abs(ranges[0].start.seconds - 1) < 0.1)
    #expect(abs(ranges[0].end.seconds - 2) < 0.15)
    #expect(abs(ranges[1].start.seconds - 3.5) < 0.1)
  }

  @Test
  func `silence holds no speech`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 3, bursts: [])
    #expect(try await SpeechActivity.detect(in: url).ranges.isEmpty)
  }

  @Test
  func `a hissing background reads a higher noise floor than a clean one`() async throws {
    let bursts = [(1.0, 2.0), (3.5, 4.5)]
    let clean = try await SpeechActivity
      .detect(in: AudioFixture.makeBursts(seconds: 6, bursts: bursts)).noiseFloor
    let noisy = try await SpeechActivity
      .detect(in: AudioFixture.makeBursts(seconds: 6, bursts: bursts, noise: 0.01)).noiseFloor
    #expect(clean < -90)
    // why: the 16 kHz analysis hears only the hiss below 8 kHz, about -50 dBFS of it.
    #expect(abs(noisy - -50) < 5)
  }
}
