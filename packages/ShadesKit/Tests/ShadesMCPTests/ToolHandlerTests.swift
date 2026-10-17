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
