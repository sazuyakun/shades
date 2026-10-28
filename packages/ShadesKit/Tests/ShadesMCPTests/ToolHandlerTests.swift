import Foundation
import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesTestSupport
import Testing

@MainActor
struct ToolHandlerTests {

  // MARK: Internal

  @Test
  func `an unknown tool returns an error result`() async {
    let result = await handler.call("explode", arguments: [:])
    #expect(result.isError)
  }

  @Test
  func `a missing argument is named in the error`() async {
    let result = await handler.call("import_media", arguments: [:])
    #expect(result.isError)
    #expect(result.text.contains("path"))
  }

  @Test
  func `an argument an edit doesn't take is named in the error and changes nothing`(
  ) async throws {
    let mediaID = try await importFixture()
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID)])
    let clip = try #require(editor.project.timeline.allClips.first)
    let result = await handler.call(
      "trim_clip",
      arguments: ["clip_id": .string(clip.id.uuidString), "edge": "end", "to": 0.5],
    )
    #expect(result.isError)
    #expect(result.text.contains("edge, to"))
    #expect(result.text.contains("start"))
  }

  @Test
  func `a built-in tool rejects an argument it doesn't take`() async {
    let result = await handler.call("get_project", arguments: ["verbose": true])
    #expect(result.isError)
    #expect(result.text.contains("verbose"))
  }

  @Test
  func `media lengths are reported in frames as well as seconds`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 2)
    let fps = editor.project.timeline.format.framesPerSecond
    let result = await handler.call("import_media", arguments: ["path": .string(url.path)])
    #expect(result.text.contains("(\(2 * fps) frames at \(fps) fps)"))
    let project = await handler.call("get_project", arguments: [:])
    #expect(project.text.contains("\"frames\" : \(2 * fps)"))
  }

  @Test
  func `edits report the clips they created`() async throws {
    let mediaID = try await importFixture()
    let result = await handler.call("append_clip", arguments: ["media_id": .string(mediaID)])
    let clip = try #require(editor.project.timeline.allClips.first)
    #expect(result.text.contains(clip.id.uuidString))
    #expect(result.text.contains("on V1"))
  }

  @Test
  func `render_frame returns a PNG image`() async throws {
    let mediaID = try await importFixture()
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID)])
    let result = await handler.call("render_frame", arguments: ["seconds": 0.5])
    guard case .png(let png) = result.content.first else {
      Issue.record("expected an image")
      return
    }
    #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
  }

  @Test
  func `a batch is one undo step`() async throws {
    let mediaID = try await importFixture()
    let append: JSONValue = ["tool": "append_clip", "arguments": ["media_id": .string(mediaID)]]
    let result = await handler.call("batch", arguments: ["edits": [append, append]])
    #expect(!result.isError)
    #expect(editor.project.timeline.allClips.count == 2)
    _ = await handler.call("undo", arguments: [:])
    #expect(editor.project.timeline.allClips.isEmpty)
  }

  @Test
  func `a bad edit in a batch names it and changes nothing`() async throws {
    let mediaID = try await importFixture()
    let good: JSONValue = ["tool": "append_clip", "arguments": ["media_id": .string(mediaID)]]
    let bad: JSONValue = ["tool": "split_clip", "arguments": [:]]
    let result = await handler.call("batch", arguments: ["edits": [good, bad]])
    #expect(result.isError)
    #expect(result.text.contains("edit 2"))
    #expect(editor.project.timeline.allClips.isEmpty)
  }

  @Test
  func `linked clips show in get_project and move together`() async throws {
    let mediaID = try await importFixture()
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID)])
    _ = await handler.call("place_on_top", arguments: ["media_id": .string(mediaID), "at": 0])
    let ids = editor.project.timeline.allClips.map { JSONValue.string($0.id.uuidString) }
    let linked = await handler.call("link_clips", arguments: ["clip_ids": .array(ids)])
    #expect(!linked.isError)
    let summary = await handler.call("get_project", arguments: [:])
    #expect(summary.text.contains("linked_to"))
    _ = await handler.call("move_clip", arguments: ["clip_id": ids[0], "to": 2])
    #expect(editor.project.timeline.allClips.allSatisfy { $0.timelineStart.seconds == 2 })
  }

  // MARK: Private

  private let editor = Editor()
  private let player = Player()
  private let activity = ActivityLog()

  private var handler: ToolHandler {
    ToolHandler(editor: editor, player: player, activity: activity)
  }

  /// Imports a 1 s blue test video and returns its media ID.
  private func importFixture() async throws -> String {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255)
    _ = await handler.call("import_media", arguments: ["path": .string(url.path)])
    return try #require(editor.project.media.first?.id.uuidString)
  }

}
