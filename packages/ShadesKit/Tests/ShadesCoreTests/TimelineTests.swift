import Foundation
import ShadesCore
import Testing

// MARK: - TimelineTests

struct TimelineTests {
  @Test
  func `an empty timeline has no duration`() {
    #expect(Timeline().duration == .zero)
  }

  @Test
  func `new timelines have one video and one audio track`() {
    #expect(Timeline().tracks.map(\.kind) == [.video, .audio])
  }

  @Test
  func `duration is the end of the longest track`() {
    let timeline = Timeline(tracks: [
      Track(kind: .video, clips: [clip(at: 3, length: 2)]),
      Track(kind: .video),
    ])
    #expect(timeline.duration == MediaTime(seconds: 5))
  }

  @Test
  func `tracks are labeled by kind, bottom up`() {
    let timeline = Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio),
      Track(kind: .video),
    ])
    #expect(timeline.tracks.map(timeline.label(of:)) == ["V1", "A1", "V2"])
  }

  @Test
  func `a clip can be found by its ID`() throws {
    let target = clip(at: 0, length: 1)
    let timeline = Timeline(tracks: [Track(kind: .video), Track(kind: .video, clips: [target])])
    let location = try #require(timeline.location(ofClip: target.id))
    #expect(location.track == 1)
    #expect(location.clip == 0)
    #expect(timeline.clip(withID: target.id) == target)
  }
}

/// A clip of made-up media, placed `start` seconds in and `length` seconds long.
func clip(at start: Double, length: Double, sourceStart: Double = 0) -> Clip {
  Clip(
    mediaID: UUID(),
    sourceStart: MediaTime(seconds: sourceStart),
    duration: MediaTime(seconds: length),
    timelineStart: MediaTime(seconds: start),
  )
}
