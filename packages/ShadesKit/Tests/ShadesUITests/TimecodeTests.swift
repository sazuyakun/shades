@testable import ShadesUI
import Testing

@MainActor
struct TimecodeTests {
  @Test
  func `timecode counts frames at the project's rate`() {
    #expect(Timecode.full(42.75, framesPerSecond: 24) == "00:00:42:18")
    #expect(Timecode.full(61.5, framesPerSecond: 30) == "00:01:01:15")
  }

  @Test
  func `an invalid time reads as zero instead of crashing`() {
    #expect(Timecode.full(.nan, framesPerSecond: 24) == "00:00:00:00")
    #expect(Timecode.full(.infinity, framesPerSecond: 24) == "00:00:00:00")
    #expect(Timecode.short(.nan) == "00:00")
  }
}
