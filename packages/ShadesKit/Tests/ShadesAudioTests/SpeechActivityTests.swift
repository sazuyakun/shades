import ShadesAudio
import ShadesCore
import ShadesTestSupport
import Testing

struct SpeechActivityTests {
  @Test
  func `sound between silences is found as speech`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 6, bursts: [(1, 2), (3.5, 4.5)])
    let ranges = try await SpeechActivity.detect(in: url)
    #expect(ranges.count == 2)
    #expect(abs(ranges[0].start.seconds - 1) < 0.1)
    #expect(abs(ranges[0].end.seconds - 2) < 0.15)
    #expect(abs(ranges[1].start.seconds - 3.5) < 0.1)
  }

  @Test
  func `silence holds no speech`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 3, bursts: [])
    #expect(try await SpeechActivity.detect(in: url).isEmpty)
  }
}
