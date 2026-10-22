import Foundation
import ShadesCommands
import ShadesCore
import ShadesTestSupport
import ShadesUI
import Testing

/// Quality gate 2: Claude's analysis and Polish tools over real HTTP, against a real workspace.
@MainActor
struct PolishScenarioTests {

  @Test
  func `analyse sound, propose Polish, apply it: the pauses and hiss are gone, the level set`(
  ) async throws {
    let workspace = try await ScenarioWorkspace.open(port: 47_496)
    defer { workspace.server.stop() }
    let client = MCPTestClient(port: 47_496)

    let talk = try AudioFixture.makeBursts(seconds: 6, bursts: [(1, 2), (4, 5)], noise: 0.02)
    _ = try await client.tool("import_media", ["path": .string(talk.path)])
    let mediaID = try #require(workspace.editor.project.media.first?.id.uuidString)
    _ = try await client.tool("append_clip", ["media_id": .string(mediaID)])
    _ = try await client.tool("analyze_audio")
    await workspace.jobs.waitUntilIdle()

    let plan = try await client.tool("polish_propose", ["start": 0, "end": 6, "track": "A1"])
    #expect(plan.resultText.contains("Cut silences"))
    #expect(plan.resultText.contains("Reduce background noise"))
    #expect(plan.resultText.contains("Set the loudness"))
    let applied = try await client.tool("polish_apply")
    #expect(applied.resultText.contains("Polished"))
    #expect(workspace.editor.project.timeline.allClips.allSatisfy { $0.cleanSound })
    // why: the loud test tone needs turning down to land at -14 LUFS.
    #expect(workspace.editor.project.timeline.gain < 1)
    // Three pauses (before, between, after) come out; about 2 s of speech (plus padding) stays.
    #expect(workspace.editor.project.timeline.duration.seconds < 3.2)
    _ = try await client.tool("undo")
    #expect(workspace.editor.project.timeline.duration == MediaTime(seconds: 6))
  }

}
