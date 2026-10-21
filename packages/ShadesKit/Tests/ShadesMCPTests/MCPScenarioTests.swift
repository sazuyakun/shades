import Foundation
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMCP
import ShadesTestSupport
import Testing

/// Quality gate 2: scripted Claude sessions over real HTTP against the real engine.
@MainActor
@Suite(.serialized)
struct MCPScenarioTests {

  // MARK: Internal

  @Test
  func `a rough cut: import, place, split, ripple delete, look, undo`() async throws {
    let editor = Editor()
    let server = MCPServer(editor: editor, player: Player(), port: 47_480)
    server.start()
    defer { server.stop() }
    await waitUntilReady(server)
    let client = MCPTestClient(port: 47_480)

    let red = try await VideoFixture.make(red: 255, green: 0, blue: 0, seconds: 2)
    let blue = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 2)
    _ = try await client.tool("import_media", ["path": .string(red.path)])
    _ = try await client.tool("import_media", ["path": .string(blue.path)])
    let ids = editor.project.media.map { JSONValue.string($0.id.uuidString) }
    let append0: JSONValue = ["tool": "append_clip", "arguments": ["media_id": ids[0]]]
    let append1: JSONValue = ["tool": "append_clip", "arguments": ["media_id": ids[1]]]
    let placed = try await client.tool("batch", ["edits": [append0, append1]])
    #expect(!placed.isErrorResult)
    #expect(editor.project.timeline.duration == MediaTime(seconds: 4))

    let first = try #require(editor.project.timeline.tracks[0].clips.first)
    _ = try await client.tool("split_clip", ["clip_id": .string(first.id.uuidString), "at": 1])
    let tail = editor.project.timeline.tracks[0].clips[1]
    let deleted = try await client.tool(
      "delete_clips",
      ["clip_ids": [.string(tail.id.uuidString)], "ripple": true],
    )
    #expect(!deleted.isErrorResult)
    #expect(editor.project.timeline.duration == MediaTime(seconds: 3))

    let frame = try await client.tool("render_frame", ["seconds": 1.5, "max_side": 160])
    guard
      case .array(let content) = frame["content"], let data = content.first?["data"]?.stringValue,
      let png = Data(base64Encoded: data)
    else {
      Issue.record("render_frame returned no image")
      return
    }
    #expect(try GoldenFrame.matches(png, named: "scenario-blue-after-cut", in: golden))

    _ = try await client.tool("undo")
    #expect(editor.project.timeline.duration == MediaTime(seconds: 4))
    let summary = try await client.tool("get_project")
    #expect(summary.resultText.contains("\"label\" : \"V1\""))
  }

  @Test
  func `slow motion, a ramp and a freeze frame over MCP`() async throws {
    let editor = Editor()
    let server = MCPServer(editor: editor, player: Player(), port: 47_481)
    server.start()
    defer { server.stop() }
    await waitUntilReady(server)
    let client = MCPTestClient(port: 47_481)

    let red = try await VideoFixture.make(red: 255, green: 0, blue: 0, seconds: 2)
    _ = try await client.tool("import_media", ["path": .string(red.path)])
    let media = try #require(editor.project.media.first)
    _ = try await client.tool("append_clip", ["media_id": .string(media.id.uuidString)])
    let clip = try #require(editor.project.timeline.tracks[0].clips.first)
    let id = JSONValue.string(clip.id.uuidString)

    let slowed = try await client.tool("set_clip", ["clip_id": id, "speed": 0.5])
    #expect(!slowed.isErrorResult)
    #expect(editor.project.timeline.duration == MediaTime(seconds: 4))

    let ramp: JSONValue = [
      ["property": "speed", "at": 0, "value": 0.5, "easing": "easeInOut"],
      ["property": "speed", "at": 2, "value": 2],
    ]
    let ramped = try await client.tool("set_keyframes", ["clip_id": id, "keyframes": ramp])
    #expect(!ramped.isErrorResult)
    #expect(editor.project.timeline.duration < MediaTime(seconds: 4))

    let frozen = try await client.tool(
      "freeze_frame",
      ["clip_id": id, "at": 0.5, "duration": 1],
    )
    #expect(!frozen.isErrorResult)
    #expect(editor.project.timeline.tracks[0].clips.count == 3)
    let summary = try await client.tool("get_project")
    #expect(summary.resultText.contains("\"freeze_frame\" : true"))
    #expect(summary.resultText.contains("\"property\" : \"speed\""))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  private func waitUntilReady(_ server: MCPServer) async {
    for _ in 0 ..< 200 where server.status == .starting {
      try? await Task.sleep(for: .milliseconds(10)) // why: a cancelled sleep just checks again.
    }
  }

}
