import AVFoundation
import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

@MainActor
struct PlayerTests {

  // MARK: Internal

  @Test
  func `a fresh player loads with a real playhead, not NaN`() async throws {
    let project = try await oneClipProject()
    let player = Player()
    try await player.load(project)
    #expect(player.currentTime.isFinite)
    #expect(player.currentTime == 0)
  }

  @Test
  func `a seek before the project loads wins over where the last session left off`(
  ) async throws {
    let project = try await oneClipProject()
    let player = Player()
    player.cue(toSeconds: 0.2)
    await player.seek(toSeconds: 0.75)
    try await player.load(project)
    #expect(abs(player.currentTime - 0.75) < 0.01)
  }

  @Test
  func `loading an empty project puts the playhead back at the start`() async throws {
    let player = Player()
    try await player.load(oneClipProject())
    await player.seek(toSeconds: 0.75)
    player.play()
    player.pause()
    player.cue(toSeconds: 0)
    try await player.load(Project())
    // why: AVFoundation reports the old time a moment later; it mustn't move the playhead back.
    try await Task.sleep(for: .milliseconds(200))
    #expect(player.currentTime == 0)
  }

  @Test
  func `a new cut-out rebuilds playback so depth slots can use it`() async throws {
    let project = try await oneClipProject()
    let player = Player()
    try await player.load(project)
    let before = player.avPlayer.currentItem
    let mediaID = try #require(project.media.first?.id)
    player.mattes[mediaID] = try await VideoFixture.make(red: 255, green: 255, blue: 255)
    try await player.load(project)
    #expect(player.avPlayer.currentItem !== before)
  }

  @Test
  func `loads running at once share files without breaking each other`() async throws {
    let project = try await oneClipProject()
    let player = Player()
    let mediaID = try #require(project.media.first?.id)
    player.mattes[mediaID] = try await VideoFixture.make(red: 255, green: 255, blue: 255)
    let loads = (0 ..< 4).map { _ in Task { try await player.load(project) } }
    for load in loads {
      try await load.value
    }
  }

  @Test
  func `a track whose sound changes format between clips keeps playing`() async throws {
    let video = try await VideoFixture.make(red: 0, green: 200, blue: 0, seconds: 4)
    let picture = Media(
      url: video,
      duration: MediaTime(seconds: 4),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    // why: a stereo sound then a mono one on one track froze playback once its meters tapped it.
    let sounds = try [2, 1].map { channels in
      try Media(
        url: AudioFixture.makeTone(seconds: 2, channels: channels),
        duration: MediaTime(seconds: 2),
        width: 0,
        height: 0,
        hasVideo: false,
        hasAudio: true,
      )
    }
    let project = Project(media: [picture] + sounds, timeline: Timeline(tracks: [
      Track(kind: .video, clips: [Clip(
        mediaID: picture.id,
        sourceStart: .zero,
        duration: picture.duration,
        timelineStart: .zero,
      )]),
      Track(kind: .audio, clips: sounds.enumerated().map { index, sound in
        Clip(
          mediaID: sound.id,
          sourceStart: .zero,
          duration: sound.duration,
          timelineStart: MediaTime(seconds: 2 * Double(index)),
        )
      }),
    ]))
    let player = Player()
    try await player.load(project)
    player.avPlayer.currentItem?.add(AVPlayerItemVideoOutput(pixelBufferAttributes: nil))
    player.play()
    // why: a busy machine starts playback late; a frozen player never moves at all.
    for _ in 0 ..< 30 where player.currentTime <= 0.5 {
      try await Task.sleep(for: .milliseconds(100))
    }
    player.pause()
    #expect(player.currentTime > 0.5)
  }

  // MARK: Private

  private func oneClipProject() async throws -> Project {
    let url = try await VideoFixture.make(red: 0, green: 200, blue: 0)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    var project = Project(media: [media])
    project.timeline.tracks[0].clips = [Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )]
    return project
  }

}
