import Foundation
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMedia
import ShadesTestSupport
import ShadesUI
import Testing

/// The mixer against a real workspace: panning mono sound makes its stereo copy, then pans it.
@MainActor
struct MixerFlowTests {

  @Test
  func `panning a mono track makes a stereo copy that playback and export pan`() async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_498)
    defer { workspace.server.stop() }
    let media = try await MediaLoader.load(AudioFixture.makeTone(seconds: 2, amplitude: 0.5))
    try workspace.editor.perform(AddMedia(media: media))
    try workspace.editor.perform(AppendClip(mediaID: media.id))
    try workspace.editor.perform(SetTrack(track: "A1", pan: -1))
    workspace.projectDidChange()
    await workspace.jobs.waitUntilIdle()
    #expect(workspace.player.stereoSound[media.id] != nil)
    let reader = MixReader(
      project: workspace.editor.project,
      stereoSound: workspace.player.stereoSound,
    )
    var left: Float = 0
    var right: Float = 0
    while let chunk = try await reader.nextChunk() {
      for index in stride(from: 0, to: chunk.count - 1, by: 2) {
        left = max(left, abs(chunk[index]))
        right = max(right, abs(chunk[index + 1]))
      }
    }
    #expect(left > 0.4)
    #expect(right < 0.01)
  }

}
