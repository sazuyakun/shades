import Foundation
import ShadesCore
import Testing

struct TrackEditingTests {

  // MARK: Internal

  @Test
  func `splitting a clip keeps its total length and source`() throws {
    var track = Track(kind: .video, clips: [clip(at: 1, length: 4, sourceStart: 10)])
    let split = track.split(at: seconds(3))
    let rightID = try #require(split)
    #expect(track.clips.count == 2)
    #expect(track.clips[0].duration == seconds(2))
    #expect(track.clips[1].id == rightID)
    #expect(track.clips[1].timelineStart == seconds(3))
    #expect(track.clips[1].sourceStart == seconds(12))
    #expect(track.clips[1].duration == seconds(2))
  }

  @Test
  func `splitting on a clip's edge changes nothing`() {
    var track = Track(kind: .video, clips: [clip(at: 1, length: 4)])
    #expect(track.split(at: seconds(1)) == nil)
    #expect(track.split(at: seconds(5)) == nil)
    #expect(track.clips.count == 1)
  }

  @Test
  func `clearing a range trims clips across its edges and removes clips inside`() {
    var track = Track(kind: .video, clips: [
      clip(at: 0, length: 3),
      clip(at: 3, length: 1),
      clip(at: 4, length: 3),
    ])
    track.clear(from: seconds(2), to: seconds(5))
    #expect(track.clips.map(\.timelineStart) == [seconds(0), seconds(5)])
    #expect(track.clips.map(\.duration) == [seconds(2), seconds(2)])
    #expect(track.isClear(from: seconds(2), to: seconds(5)))
  }

  @Test
  func `shifting moves only what starts at or after the time`() {
    var track = Track(kind: .video, clips: [clip(at: 0, length: 4), clip(at: 5, length: 1)])
    track.shift(from: seconds(2), by: seconds(3))
    #expect(track.clips.map(\.timelineStart) == [seconds(0), seconds(5), seconds(8)])
  }

  @Test
  func `added clips stay in time order`() {
    var track = Track(kind: .video, clips: [clip(at: 0, length: 1), clip(at: 5, length: 1)])
    track.add(clip(at: 2, length: 1))
    #expect(track.clips.map(\.timelineStart) == [seconds(0), seconds(2), seconds(5)])
  }

  @Test
  func `closing gaps plays clips back to back from the start`() {
    var track = Track(kind: .video, clips: [clip(at: 1, length: 2), clip(at: 6, length: 1)])
    track.closeGaps()
    #expect(track.clips.map(\.timelineStart) == [seconds(0), seconds(2)])
    #expect(track.end == seconds(3))
  }

  // MARK: Private

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

}
