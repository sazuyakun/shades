import Foundation
import ShadesCommands
import ShadesCore
import ShadesEngine
@testable import ShadesMCP
import ShadesTestSupport
import Testing

@MainActor
struct ActivityLogTests {

  // MARK: Internal

  @Test
  func `edits Claude makes are steps of one request, with the clips they changed`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255)
    _ = await handler.call("import_media", arguments: ["path": .string(url.path)])
    let mediaID = try #require(editor.project.media.first?.id)
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    let clipID = try #require(editor.project.timeline.allClips.first?.id)
    let request = try #require(activity.requests.first)
    #expect(activity.requests.count == 1)
    #expect(request.steps.map(\.title) == ["Import Media", "Append Clip"])
    #expect(request.changedClipIDs == [clipID])
    #expect(request.addedClipCount == 1)
    #expect(activity.recentEntry?.title == "Append Clip")
    #expect(activity.recentlyChangedClipIDs == [clipID])
  }

  @Test
  func `reading and previewing are not logged`() async {
    _ = await handler.call("get_project", arguments: [:])
    _ = await handler.call("play", arguments: [:])
    #expect(activity.requests.isEmpty)
  }

  @Test
  func `a failed edit is logged as an error`() async {
    _ = await handler.call("append_clip", arguments: ["media_id": "not-a-uuid"])
    #expect(activity.requests.first?.steps.first?.isError == true)
  }

  @Test
  func `start_request names a new request, and each request starts with one snapshot`()
    async throws
  {
    var started = [ClaudeRequest.ID]()
    let handler = handler
    handler.beforeRequest = { started.append($0) }
    let mediaID = try await importClip(with: handler)
    _ = await handler.call("start_request", arguments: ["title": "Cut it together"])
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    #expect(activity.requests.map(\.title) == ["Cut it together", "Import Media"])
    #expect(activity.requests.first?.steps.count == 2)
    #expect(started == Array(activity.requests.map(\.id).reversed()))
  }

  @Test
  func `edits after a quiet spell start a new request`() {
    let now = Date.now
    let first = activity.requestForEdit(at: now)
    let soon = activity.requestForEdit(at: now + 30)
    let later = activity.requestForEdit(at: now + 30 + ActivityLog.requestGap)
    #expect(first.isNew)
    #expect(soon.id == first.id && !soon.isNew)
    #expect(later.isNew && later.id != first.id)
  }

  @Test
  func `undoing a request keeps the edits of a later one`() async throws {
    let mediaID = try await importClip(with: handler)
    let media = JSONValue.string(mediaID.uuidString)
    _ = await handler.call("start_request", arguments: ["title": "Rough cut"])
    _ = await handler.call("append_clip", arguments: ["media_id": media])
    let rough = try #require(activity.requests.first?.id)
    _ = await handler.call("start_request", arguments: ["title": "Add an ending"])
    _ = await handler.call("append_clip", arguments: ["media_id": media])
    let ending = try #require(editor.project.timeline.allClips.last?.id)
    let result = await handler.call(
      "undo_request",
      arguments: ["request_id": .string(rough.uuidString)],
    )
    #expect(!result.isError)
    #expect(editor.project.timeline.allClips.map(\.id) == [ending])
  }

  @Test
  func `a request can't be undone alone when later edits changed the same clips`() async throws {
    let mediaID = try await importClip(with: handler)
    _ = await handler.call("start_request", arguments: ["title": "Rough cut"])
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    let rough = try #require(activity.requests.first?.id)
    let clipID = try #require(editor.project.timeline.allClips.first?.id)
    try editor.perform(SetClip(clipID: clipID, opacity: 0.5))
    let before = editor.project
    let result = await handler.call(
      "undo_request",
      arguments: ["request_id": .string(rough.uuidString)],
    )
    #expect(result.isError)
    #expect(result.text.contains("Later edits changed the same things"))
    #expect(editor.project == before)
  }

  @Test
  func `a background job's edit is logged under its request and undone with it`() async throws {
    let mediaID = try await importClip(with: handler)
    _ = await handler.call("start_request", arguments: ["title": "Split the sound"])
    let request = try #require(activity.requests.first?.id)
    let before = editor.project
    try editor.perform(AppendClip(mediaID: mediaID))
    activity.record(
      "Use Stems",
      summary: "Laid the stems.",
      from: before,
      to: editor.project,
      in: request,
    )
    #expect(activity.requests.first?.steps.map(\.title) == ["Use Stems"])
    try activity.undo(request, in: editor)
    #expect(editor.project.timeline.allClips.isEmpty)
  }

  @Test
  func `the History reads back as it was saved and still undoes`() async throws {
    let mediaID = try await importClip(with: handler)
    _ = await handler.call("start_request", arguments: ["title": "Rough cut"])
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    let data = try JSONEncoder().encode(activity.requests)
    let reopened = ActivityLog()
    reopened.load(try JSONDecoder().decode([ClaudeRequest].self, from: data))
    #expect(reopened.requests == activity.requests)
    let rough = try #require(reopened.requests.first?.id)
    try reopened.undo(rough, in: editor)
    #expect(editor.project.timeline.allClips.isEmpty)
  }

  @Test
  func `get_history lists the requests with what they did`() async throws {
    let mediaID = try await importClip(with: handler)
    _ = await handler.call("start_request", arguments: ["title": "Rough cut"])
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    let result = await handler.call("get_history", arguments: [:])
    #expect(result.text.contains("Rough cut"))
    #expect(result.text.contains("\"clips_added\" : 1"))
  }

  // MARK: Private

  private let editor = Editor()
  private let player = Player()
  private let activity = ActivityLog()

  private var handler: ToolHandler {
    ToolHandler(editor: editor, player: player, activity: activity)
  }

  /// Imports a test clip over MCP and returns its media ID.
  private func importClip(with handler: ToolHandler) async throws -> Media.ID {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255)
    _ = await handler.call("import_media", arguments: ["path": .string(url.path)])
    return try #require(editor.project.media.first?.id)
  }

}
