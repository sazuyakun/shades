import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct SpeedCommandTests {

  // MARK: Internal

  @Test
  func `twice the speed halves a clip and pulls later clips in`() throws {
    var (project, first, second) = twoClips()
    try SetClip(clipID: first, speed: 2).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips[0].duration == seconds(2))
    #expect(clips[0].sourceEnd == seconds(4))
    #expect(clips[1].id == second && clips[1].timelineStart == seconds(2))
  }

  @Test
  func `half speed keeps a clip's last frame and pushes later clips out`() throws {
    var (project, first, _) = twoClips()
    try SetClip(clipID: first, speed: 0.5).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips[0].duration == seconds(8))
    #expect(clips[0].sourceEnd == seconds(4))
    #expect(clips[1].timelineStart == seconds(8))
  }

  @Test
  func `only moving video and sound has a speed, from 0.1 to 10`() throws {
    var (project, first, _) = twoClips()
    let text = Clip(
      source: .text(TextContent(text: "hi")),
      sourceStart: .zero,
      duration: seconds(2),
      timelineStart: .zero,
    )
    project.timeline.tracks.append(Track(kind: .text, clips: [text]))
    #expect(throws: CommandError.self) { try SetClip(clipID: text.id, speed: 2).apply(to: &project)
    }
    for speed in [0, 0.05, 20] {
      #expect(throws: CommandError.self) {
        try SetClip(clipID: first, speed: speed).apply(to: &project)
      }
    }
  }

  @Test
  func `speed keyframes ramp a clip, keeping its frames and moving later clips`() throws {
    var (project, first, _) = twoClips()
    try SetKeyframes(clipID: first, keyframes: [
      SetKeyframes.Key(property: .speed, at: seconds(0), value: 1, easing: nil),
      SetKeyframes.Key(property: .speed, at: seconds(2), value: 3, easing: nil),
    ]).apply(to: &project)
    // why: 1× rising to 3× over the first 2 s of source takes ln 3 s, then 2 s at 3× takes 2/3 s.
    let clips = project.timeline.tracks[0].clips
    #expect(clips[0].duration == MediaTime(seconds: log(3) + 2.0 / 3).roundedToFrame(at: 24))
    #expect(abs((clips[0].sourceEnd - seconds(4)).seconds) < 0.1)
    #expect(clips[1].timelineStart == clips[0].timelineEnd)
    try RemoveKeyframes(clipID: first, property: .speed).apply(to: &project)
    let restored = project.timeline.tracks[0].clips[0]
    #expect(abs((restored.duration - seconds(4)).seconds) <= 1.0 / 24)
  }

  @Test
  func `a freeze frame holds the frame between the clip's halves`() throws {
    var (project, first, second) = twoClips()
    try FreezeFrame(clipID: first, at: seconds(1), duration: seconds(2)).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips.map(\.timelineStart) == [seconds(0), seconds(1), seconds(3), seconds(6)])
    #expect(clips[1].isFrozen && clips[1].sourceStart == seconds(1))
    #expect(clips[1].duration == seconds(2))
    #expect(clips[2].sourceStart == seconds(1) && clips[2].sourceEnd == seconds(4))
    #expect(clips[3].id == second)
  }

  @Test
  func `a freeze at a clip's end holds its last frame after it`() throws {
    var (project, first, _) = twoClips()
    try FreezeFrame(clipID: first, at: seconds(4), duration: seconds(1)).apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips[1].sourceStart == seconds(4) - project.timeline.format.frameDuration)
    #expect(clips[1].timelineStart == seconds(4) && clips[2].timelineStart == seconds(5))
  }

  @Test
  func `a freeze frame has no speed, motion or sound to change`() throws {
    var (project, first, _) = twoClips()
    try FreezeFrame(clipID: first, at: seconds(1), duration: seconds(2)).apply(to: &project)
    let freeze = project.timeline.tracks[0].clips[1]
    #expect(freeze.gain(at: seconds(2)) == 0)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: freeze.id, speed: 2).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetKeyframes(clipID: freeze.id, keyframes: [
        SetKeyframes.Key(property: .scale, at: seconds(2), value: 2, easing: nil)
      ]).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try FreezeFrame(clipID: freeze.id, at: seconds(2), duration: seconds(1)).apply(to: &project)
    }
    try TrimClip(clipID: freeze.id, end: seconds(2.5)).apply(to: &project)
    #expect(project.timeline.tracks[0].clips[1].duration == seconds(1.5))
  }

  @Test
  func `a fast clip can't be trimmed past the end of its media`() throws {
    var (project, first, second) = twoClips()
    try DeleteClips(clipIDs: [second]).apply(to: &project)
    try SetClip(clipID: first, speed: 2).apply(to: &project)
    try TrimClip(clipID: first, end: seconds(5)).apply(to: &project)
    #expect(project.timeline.tracks[0].clips[0].sourceEnd == seconds(10))
    #expect(throws: CommandError.self) {
      try TrimClip(clipID: first, end: seconds(6)).apply(to: &project)
    }
  }

  @Test
  func `the halves of a split ramp join back into one clip`() throws {
    var (project, first, _) = twoClips()
    try SetKeyframes(clipID: first, keyframes: [
      SetKeyframes.Key(property: .speed, at: seconds(0), value: 0.5, easing: .easeInOut),
      SetKeyframes.Key(property: .speed, at: seconds(4), value: 2, easing: nil),
    ]).apply(to: &project)
    let ramped = project.timeline.tracks[0].clips[0]
    try SplitClip(clipID: first, at: seconds(2)).apply(to: &project)
    let right = project.timeline.tracks[0].clips[1].id
    try JoinClips(clipIDs: [first, right]).apply(to: &project)
    #expect(project.timeline.tracks[0].clips[0] == ramped)
  }

  @Test
  func `detached sound keeps the clip's speed`() throws {
    var (project, first, _) = twoClips()
    try SetClip(clipID: first, speed: 2).apply(to: &project)
    try DetachAudio(clipID: first).apply(to: &project)
    let sound = try #require(project.timeline.tracks[1].clips.first)
    #expect(sound.speed == 2 && sound.duration == seconds(2) && sound.sourceEnd == seconds(4))
  }

  // MARK: Private

  /// Ten seconds of footage on V1 twice: 0–4 s (source 0–4 s), then 4–6 s (source 6–8 s).
  private func twoClips() -> (Project, Clip.ID, Clip.ID) {
    let media = makeMedia(seconds: 10)
    let first = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: seconds(4),
      timelineStart: .zero,
    )
    let second = Clip(
      mediaID: media.id,
      sourceStart: seconds(6),
      duration: seconds(2),
      timelineStart: seconds(4),
    )
    let project = Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video, clips: [first, second]),
      Track(kind: .audio),
    ]))
    return (project, first.id, second.id)
  }

}
