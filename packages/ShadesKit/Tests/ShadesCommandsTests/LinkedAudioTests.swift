import Foundation
import ShadesCommands
import ShadesCore
import Testing

/// A video and its detached sound stay together through every edit until they're unlinked.
struct LinkedAudioTests {

  // MARK: Internal

  @Test
  func `detached sound is linked to its video and moves with it`() throws {
    var project = try detached()
    try MoveClip(clipID: video(project).id, to: seconds(2)).apply(to: &project)
    #expect(try video(project).timelineStart == seconds(2))
    #expect(try sound(project).timelineStart == seconds(2))
  }

  @Test
  func `trimming the video trims its sound by the same amount, rippling both tracks`() throws {
    var project = try detached()
    try AppendClip(mediaID: project.media[0].id, track: "A1").apply(to: &project)
    try TrimClip(clipID: video(project).id, end: seconds(6), ripple: true).apply(to: &project)
    #expect(try sound(project).timelineEnd == seconds(6))
    #expect(project.timeline.tracks[1].clips.last?.timelineStart == seconds(6))
  }

  @Test
  func `splitting cuts the sound too, and each half stays linked to its own half`() throws {
    var project = try detached()
    try SplitClip(clipID: video(project).id, at: seconds(4)).apply(to: &project)
    let videos = project.timeline.tracks[0].clips
    let sounds = project.timeline.tracks[1].clips
    #expect(videos.count == 2 && sounds.count == 2)
    try MoveClip(clipID: videos[1].id, to: seconds(12)).apply(to: &project)
    #expect(project.timeline.clip(withID: sounds[1].id)?.timelineStart == seconds(12))
    #expect(project.timeline.clip(withID: sounds[0].id)?.timelineStart == .zero)
  }

  @Test
  func `deleting the video deletes its sound, and ripple closes both tracks`() throws {
    var project = try detached()
    let media = project.media[0]
    try AppendClip(mediaID: media.id).apply(to: &project)
    try DeleteClips(clipIDs: [video(project).id], ripple: true).apply(to: &project)
    #expect(project.timeline.tracks[0].clips.count == 1)
    #expect(project.timeline.tracks[1].clips.isEmpty)
    #expect(project.timeline.tracks[0].clips.first?.timelineStart == .zero)
  }

  @Test
  func `cutting ranges from the video cuts its sound in step`() throws {
    var project = try detached()
    try RemoveRanges(ranges: [TimeRange(start: seconds(2), end: seconds(3))])
      .apply(to: &project)
    let videos = project.timeline.tracks[0].clips
    let sounds = project.timeline.tracks[1].clips
    #expect(videos.map(\.timelineStart) == sounds.map(\.timelineStart))
    #expect(videos.map(\.sourceStart) == sounds.map(\.sourceStart))
    #expect(sounds.last?.timelineEnd == seconds(9))
  }

  @Test
  func `inserting on the video's track makes room on its sound's track too`() throws {
    var project = try detached()
    try InsertClip(mediaID: project.media[0].id, at: .zero, sourceEnd: seconds(1))
      .apply(to: &project)
    #expect(try sound(project).timelineStart == seconds(1))
    #expect(project.timeline.tracks[0].clips.last?.timelineStart == seconds(1))
  }

  @Test
  func `joining the video's halves joins its sound's halves`() throws {
    var project = try detached()
    try SplitClip(clipID: video(project).id, at: seconds(4)).apply(to: &project)
    try JoinClips(clipIDs: project.timeline.tracks[0].clips.map(\.id)).apply(to: &project)
    #expect(project.timeline.tracks[1].clips.count == 1)
    #expect(project.timeline.tracks[1].clips.first?.duration == seconds(10))
  }

  @Test
  func `closing gaps keeps the sound under its video`() throws {
    var project = try detached()
    try MoveClip(clipID: video(project).id, to: seconds(3)).apply(to: &project)
    try CloseGaps().apply(to: &project)
    #expect(try video(project).timelineStart == .zero)
    #expect(try sound(project).timelineStart == .zero)
  }

  @Test
  func `unlinked sound stays put, and linking pairs them again`() throws {
    var project = try detached()
    try UnlinkClips(clipIDs: [video(project).id]).apply(to: &project)
    try MoveClip(clipID: video(project).id, to: seconds(2)).apply(to: &project)
    #expect(try sound(project).timelineStart == .zero)
    try LinkClips(clipIDs: [video(project).id, sound(project).id]).apply(to: &project)
    try MoveClip(clipID: video(project).id, to: seconds(5)).apply(to: &project)
    #expect(try sound(project).timelineStart == seconds(3))
  }

  @Test
  func `linking needs clips on two tracks`() throws {
    var project = try detached()
    #expect(throws: CommandError.self) {
      try LinkClips(clipIDs: [video(project).id]).apply(to: &project)
    }
  }

  @Test
  func `a move that would push the linked sound before zero is refused`() throws {
    var project = try detached()
    try UnlinkClips(clipIDs: [video(project).id]).apply(to: &project)
    try MoveClip(clipID: video(project).id, to: seconds(1)).apply(to: &project)
    try LinkClips(clipIDs: [video(project).id, sound(project).id]).apply(to: &project)
    #expect(throws: CommandError.self) {
      try MoveClip(clipID: video(project).id, to: .zero).apply(to: &project)
    }
  }

  // MARK: Private

  /// A 10 s video with sound on V1, its sound detached onto A1.
  private func detached() throws -> Project {
    let media = makeMedia(seconds: 10)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try DetachAudio(clipID: video(project).id).apply(to: &project)
    return project
  }

  private func video(_ project: Project) throws -> Clip {
    try #require(project.timeline.tracks[0].clips.first)
  }

  private func sound(_ project: Project) throws -> Clip {
    try #require(project.timeline.tracks[1].clips.first)
  }

}
