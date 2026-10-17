import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct ClipEditTests {

  // MARK: Internal

  @Test
  func `moving a clip leaves a gap and replaces what's at the destination`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try MoveClip(clipID: first.id, to: seconds(6)).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips.map(\.timelineStart) == [seconds(4), seconds(6)])
    #expect(clips[0].duration == seconds(2))
  }

  @Test
  func `moving a clip to another track keeps its time`() throws {
    var project = try twoClips()
    try AddTrack(kind: .video).apply(to: &project)
    let first = project.timeline.tracks[0].clips[0]
    try MoveClip(clipID: first.id, track: "v2").apply(to: &project)
    #expect(project.timeline.tracks[1].clips.first?.timelineStart == seconds(0))
  }

  @Test
  func `splitting cuts a clip in two`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try SplitClip(clipID: first.id, at: seconds(1.5)).apply(to: &project)
    #expect(project.timeline.tracks[0].clips.count == 3)
    #expect(throws: CommandError.self) {
      try SplitClip(clipID: first.id, at: seconds(3)).apply(to: &project)
    }
  }

  @Test
  func `deleting leaves a gap, ripple deleting closes it`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    var lifted = project
    try DeleteClips(clipIDs: [first.id]).apply(to: &lifted)
    #expect(lifted.timeline.duration == seconds(8))
    try DeleteClips(clipIDs: [first.id], ripple: true).apply(to: &project)
    #expect(project.timeline.tracks[0].clips.first?.timelineStart == seconds(0))
  }

  @Test
  func `ripple trimming the start keeps the clip in place and pulls later clips`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try TrimClip(clipID: first.id, start: seconds(1), ripple: true).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips[0].timelineStart == seconds(0))
    #expect(clips[0].sourceStart == seconds(1))
    #expect(clips[1].timelineStart == seconds(3))
  }

  @Test
  func `trimming the end without ripple leaves a gap`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try TrimClip(clipID: first.id, end: seconds(3)).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips[0].duration == seconds(3))
    #expect(clips[1].timelineStart == seconds(4))
  }

  @Test
  func `growing a clip into its neighbour needs ripple`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try TrimClip(clipID: first.id, end: seconds(3)).apply(to: &project)
    #expect(throws: CommandError.self) {
      try TrimClip(clipID: first.id, end: seconds(5)).apply(to: &project)
    }
  }

  @Test
  func `trimming past the media's end is rejected`() throws {
    var project = try twoClips()
    let second = project.timeline.tracks[0].clips[1]
    #expect(throws: CommandError.self) {
      try TrimClip(clipID: second.id, end: seconds(9), ripple: true).apply(to: &project)
    }
  }

  @Test
  func `split halves join back into one clip`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try SplitClip(clipID: first.id, at: seconds(1)).apply(to: &project)
    let halves = project.timeline.tracks[0].clips.prefix(2).map(\.id)
    try JoinClips(clipIDs: Array(halves)).apply(to: &project)
    #expect(project.timeline.tracks[0].clips.count == 2)
    #expect(project.timeline.tracks[0].clips[0].duration == seconds(4))
  }

  @Test
  func `separate clips of the same media can't be joined`() throws {
    var project = try twoClips()
    let ids = project.timeline.tracks[0].clips.map(\.id)
    #expect(throws: CommandError.self) { try JoinClips(clipIDs: ids).apply(to: &project) }
  }

  @Test
  func `set clip changes only the given fields and checks ranges`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try SetClip(clipID: first.id, scale: 1.5, opacity: 0.5, depth: .behindSubject)
      .apply(to: &project)
    let changed = project.timeline.tracks[0].clips[0]
    #expect(changed.transform.scale == 1.5)
    #expect(changed.transform.x == 0)
    #expect(changed.opacity == 0.5)
    #expect(changed.depth == .behindSubject)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: first.id, opacity: 2).apply(to: &project)
    }
  }

  @Test
  func `detaching audio moves the sound to an audio track`() throws {
    var project = try twoClips()
    let first = project.timeline.tracks[0].clips[0]
    try DetachAudio(clipID: first.id).apply(to: &project)
    #expect(project.timeline.tracks[0].clips[0].isAudioEnabled == false)
    let audio = try #require(project.timeline.tracks[1].clips.first)
    #expect(audio.timelineStart == first.timelineStart)
    #expect(audio.duration == first.duration)
    #expect(throws: CommandError.noAudio(first.id)) {
      try DetachAudio(clipID: first.id).apply(to: &project)
    }
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)

  /// V1 holding the whole 4 s video twice, back to back.
  private func twoClips() throws -> Project {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
