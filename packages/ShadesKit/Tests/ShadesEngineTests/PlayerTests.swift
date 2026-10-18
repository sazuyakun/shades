import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

@MainActor
struct PlayerTests {
  @Test
  func `a fresh player loads with a real playhead, not NaN`() async throws {
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
    let player = Player()
    try await player.load(project)
    #expect(player.currentTime.isFinite)
    #expect(player.currentTime == 0)
  }
}
