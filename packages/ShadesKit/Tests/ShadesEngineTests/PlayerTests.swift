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
