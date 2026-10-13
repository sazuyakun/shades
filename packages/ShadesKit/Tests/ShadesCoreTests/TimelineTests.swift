import Foundation
import ShadesCore
import Testing

struct TimelineTests {
  @Test
  func `an empty timeline has no duration`() {
    #expect(Timeline().duration == .zero)
  }

  @Test
  func `duration is the end of the longest track`() {
    let clip = Clip(
      mediaID: UUID(),
      sourceStart: .zero,
      duration: MediaTime(seconds: 2),
      timelineStart: MediaTime(seconds: 3),
    )
    let timeline = Timeline(tracks: [Track(name: "V1", clips: [clip]), Track(name: "V2")])
    #expect(timeline.duration == MediaTime(seconds: 5))
  }
}
