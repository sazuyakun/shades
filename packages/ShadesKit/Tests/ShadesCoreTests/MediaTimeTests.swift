import ShadesCore
import Testing

struct MediaTimeTests {
  @Test
  func `adding times with different timescales is exact`() {
    #expect(MediaTime(value: 1, timescale: 2) + MediaTime(value: 1, timescale: 3) == MediaTime(
      value: 5,
      timescale: 6,
    ))
  }

  @Test
  func `comparing works across timescales`() {
    #expect(MediaTime(value: 1, timescale: 2) < MediaTime(value: 2, timescale: 3))
    #expect(!(MediaTime(value: 2, timescale: 4) < MediaTime(value: 1, timescale: 2)))
  }

  @Test
  func `seconds are rounded to the timescale`() {
    #expect(MediaTime(seconds: 1.5, timescale: 600) == MediaTime(value: 900, timescale: 600))
  }
}
