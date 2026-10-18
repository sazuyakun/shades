import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct RemoveRangesTests {

  // MARK: Internal

  @Test
  func `ripple cutting ranges closes the track up`() throws {
    var project = try oneLongClip()
    try RemoveRanges(ranges: [range(1, 2), range(5, 6)]).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips.map(\.timelineStart) == [seconds(0), seconds(1), seconds(4)])
    #expect(clips.map(\.sourceStart) == [seconds(0), seconds(2), seconds(6)])
    #expect(project.timeline.tracks[0].end == seconds(8))
  }

  @Test
  func `overlapping ranges are cut once`() throws {
    var project = try oneLongClip()
    try RemoveRanges(ranges: [range(1, 3), range(2, 4)]).apply(to: &project)
    #expect(project.timeline.tracks[0].end == seconds(7))
  }

  @Test
  func `without ripple the cuts leave gaps`() throws {
    var project = try oneLongClip()
    try RemoveRanges(ranges: [range(1, 2)], ripple: false).apply(to: &project)
    #expect(project.timeline.tracks[0].end == seconds(10))
    #expect(project.timeline.tracks[0].clips.count == 2)
  }

  @Test
  func `other tracks don't move`() throws {
    var project = try oneLongClip()
    try AddText(text: "hi", at: seconds(5), duration: seconds(1)).apply(to: &project)
    try RemoveRanges(ranges: [range(1, 3)]).apply(to: &project)
    #expect(project.timeline.tracks.first { $0.kind == .text }?.clips.first?
      .timelineStart == seconds(5))
  }

  @Test
  func `all tracks keeps captions and b-roll in sync but leaves music playing`() throws {
    var project = try oneLongClip()
    let music = makeMedia(seconds: 10, hasVideo: false)
    project.media.append(music)
    try AppendClip(mediaID: music.id).apply(to: &project)
    try AddText(text: "late line", at: seconds(5), duration: seconds(1)).apply(to: &project)
    try RemoveRanges(ranges: [range(1, 3)], allTracks: true).apply(to: &project)
    #expect(project.timeline.tracks.first { $0.kind == .text }?.clips.first?
      .timelineStart == seconds(3))
    #expect(project.timeline.tracks.first { $0.kind == .audio }?.end == seconds(10))
  }

  @Test
  func `empty ranges are refused`() throws {
    var project = try oneLongClip()
    #expect(throws: CommandError.self) {
      try RemoveRanges(ranges: [range(2, 2)]).apply(to: &project)
    }
  }

  // MARK: Private

  private func oneLongClip() throws -> Project {
    let media = makeMedia(seconds: 10)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    return project
  }

  private func range(_ start: Double, _ end: Double) -> TimeRange {
    TimeRange(start: seconds(start), end: seconds(end))
  }

}
