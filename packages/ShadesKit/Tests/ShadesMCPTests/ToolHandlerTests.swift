import MCP
import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesTestSupport
import Testing

@MainActor
struct ToolHandlerTests {

  // MARK: Internal

  @Test
  func `Claude sees every M0 tool`() {
    #expect(ToolHandler.tools.map(\.name).sorted() == [
      "append_clip",
      "get_project",
      "import_media",
      "pause",
      "play",
      "render_frame",
      "seek",
    ])
  }

  @Test
  func `an unknown tool returns an error result`() async {
    let result = await handler.call(CallTool.Parameters(name: "explode"))
    #expect(result.isError == true)
  }

  @Test
  func `a missing argument returns an error result`() async {
    let result = await handler.call(CallTool.Parameters(name: "import_media"))
    #expect(result.isError == true)
  }

  @Test
  func `importing and appending through tools builds the timeline`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255)
    let imported = await handler.call(CallTool.Parameters(
      name: "import_media",
      arguments: ["path": .string(url.path)],
    ))
    #expect(imported.isError != true)
    let mediaID = try #require(editor.project.media.first?.id)
    let appended = await handler.call(
      CallTool.Parameters(name: "append_clip", arguments: ["media_id": .string(mediaID.uuidString)])
    )
    #expect(appended.isError != true)
    #expect(editor.project.timeline.tracks[0].clips.count == 1)
  }

  @Test
  func `render_frame returns a PNG image`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 255, blue: 0)
    _ = await handler.call(CallTool.Parameters(
      name: "import_media",
      arguments: ["path": .string(url.path)],
    ))
    let mediaID = try #require(editor.project.media.first?.id)
    _ = await handler.call(CallTool.Parameters(
      name: "append_clip",
      arguments: ["media_id": .string(mediaID.uuidString)],
    ))
    let result = await handler.call(CallTool.Parameters(
      name: "render_frame",
      arguments: ["seconds": .double(0.5)],
    ))
    guard case .image(_, let mimeType, _, _) = try #require(result.content.first) else {
      Issue.record("Expected image content, got \(result.content)")
      return
    }
    #expect(mimeType == "image/png")
  }

  // MARK: Private

  private let editor = Editor()
  private let player = Player()

  private var handler: ToolHandler {
    ToolHandler(editor: editor, player: player, activity: ActivityLog())
  }

}
