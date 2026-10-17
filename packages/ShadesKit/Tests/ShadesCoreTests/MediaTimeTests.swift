import Foundation
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

  @Test
  func `times round to the nearest frame`() {
    let time = MediaTime(seconds: 1.02).roundedToFrame(at: 24)
    #expect(time == MediaTime(seconds: 1))
    #expect(MediaTime(seconds: 1.03).roundedToFrame(at: 24) == MediaTime(
      value: 625,
      timescale: 600,
    ))
  }

  @Test
  func `subtracting times with different timescales is exact`() {
    let difference = MediaTime(value: 3, timescale: 2) - MediaTime(value: 1, timescale: 3)
    #expect(difference == MediaTime(value: 7, timescale: 6))
  }

  @Test
  func `a time decodes from plain seconds or an exact fraction`() throws {
    let decoder = JSONDecoder()
    let fromSeconds = try decoder.decode(MediaTime.self, from: Data("2.5".utf8))
    let fromFraction = try decoder.decode(
      MediaTime.self,
      from: Data(#"{"value":5,"timescale":2}"#.utf8),
    )
    #expect(fromSeconds == fromFraction)
  }

  @Test
  func `equal times are equal and hash alike across timescales`() {
    let half = MediaTime(value: 1, timescale: 2)
    let same = MediaTime(value: 300, timescale: 600)
    #expect(half == same)
    #expect(Set([half, same]).count == 1)
  }
}
