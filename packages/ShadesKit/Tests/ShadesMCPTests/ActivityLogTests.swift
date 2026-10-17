import Foundation
import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesTestSupport
import Testing

@MainActor
struct ActivityLogTests {

  // MARK: Internal

  @Test
  func `edits Claude makes are logged with the clips they changed`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255)
    _ = await handler.call("import_media", arguments: ["path": .string(url.path)])
    let mediaID = try #require(editor.project.media.first?.id)
    _ = await handler.call("append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    let clipID = try #require(editor.project.timeline.allClips.first?.id)
    #expect(activity.entries.map(\.title) == ["Append Clip", "Import Media"])
    #expect(activity.entries.first?.changedClipIDs == [clipID])
    #expect(activity.recentEntry?.title == "Append Clip")
    #expect(activity.recentlyChangedClipIDs == [clipID])
  }

  @Test
  func `reading and previewing are not logged`() async {
    _ = await handler.call("get_project", arguments: [:])
    _ = await handler.call("play", arguments: [:])
    #expect(activity.entries.isEmpty)
  }

  @Test
  func `a failed edit is logged as an error`() async {
    _ = await handler.call("append_clip", arguments: ["media_id": "not-a-uuid"])
    #expect(activity.entries.first?.isError == true)
  }

  // MARK: Private

  private let editor = Editor()
  private let player = Player()
  private let activity = ActivityLog()

  private var handler: ToolHandler {
    ToolHandler(editor: editor, player: player, activity: activity)
  }

}
