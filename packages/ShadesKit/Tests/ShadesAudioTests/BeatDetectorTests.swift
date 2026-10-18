import ShadesAudio
import ShadesCore
import ShadesTestSupport
import Testing

struct BeatDetectorTests {
  @Test(arguments: [90.0, 120.0, 150.0])
  func `a click track's tempo and beats are found`(beatsPerMinute: Double) async throws {
    let url = try AudioFixture.makeClicks(beatsPerMinute: beatsPerMinute, seconds: 12)
    let grid = try await BeatDetector.detect(in: url)
    #expect(abs(grid.beatsPerMinute - beatsPerMinute) < 3)
    let beat = 60 / beatsPerMinute
    let offsets = grid.beats.prefix(10).map { time in
      let remainder = time.seconds.truncatingRemainder(dividingBy: beat)
      return min(remainder, beat - remainder)
    }
    #expect(offsets.allSatisfy { $0 < 0.04 })
  }

  @Test
  func `a steady tone has no beats`() async throws {
    let url = try AudioFixture.makeTone(seconds: 8, frequency: 220)
    #expect(try await BeatDetector.detect(in: url).beats.isEmpty)
  }

  @Test
  func `silence has no beats`() async throws {
    let url = try AudioFixture.makeBursts(seconds: 6, bursts: [])
    #expect(try await BeatDetector.detect(in: url).beats.isEmpty)
  }
}
