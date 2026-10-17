import Foundation
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesTestSupport
@testable import ShadesUI
import SwiftUI
import Testing

@MainActor
struct EditorActionTests {

  // MARK: Internal

  @Test
  func `every action has its own shortcut`() {
    let shortcuts = EditorAction.allCases.map(\.shortcut)
    for (index, shortcut) in shortcuts.enumerated() {
      #expect(!shortcuts[(index + 1)...].contains(shortcut), "\(shortcut.label) is used twice")
    }
  }

  @Test
  func `shortcuts read the way the Mac writes them`() {
    #expect(EditorAction.detachAudio.shortcut.label == "⇧⌘L")
    #expect(EditorAction.join.shortcut.label == "⌥⌘J")
    #expect(EditorAction.rippleDelete.shortcut.label == "⇧⌫")
  }

  @Test
  func `split cuts the clip under the playhead in one undo step`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 1)
    try EditorAction.split.perform(in: context)
    #expect(editor.project.timeline.tracks[0].clips.count == 3)
    try editor.undo()
    #expect(editor.project.timeline.tracks[0].clips.count == 2)
  }

  @Test
  func `nudging moves the selection by one frame`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    let last = try #require(editor.project.timeline.tracks[0].clips.last)
    editor.selection = [last.id]
    try EditorAction.nudgeRight.perform(in: context)
    let moved = try #require(editor.project.timeline.clip(withID: last.id))
    #expect(moved.timelineStart == last.timelineStart + editor.project.timeline.format
      .frameDuration)
  }

  @Test
  func `ripple delete closes the gap`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    let first = try #require(editor.project.timeline.tracks[0].clips.first)
    editor.selection = [first.id]
    try EditorAction.rippleDelete.perform(in: context)
    #expect(editor.project.timeline.tracks[0].clips.first?.timelineStart == .zero)
  }

  @Test
  func `placing needs a media choice and says so`() async throws {
    let (_, context) = try await editing(seconds: 2, playhead: 0, choosingMedia: false)
    #expect(throws: CommandError.self) { try EditorAction.append.perform(in: context) }
  }

  // MARK: Private

  /// An editor with a test clip placed twice on V1, playing at `playhead` seconds.
  private func editing(
    seconds: Int,
    playhead: Double,
    choosingMedia: Bool = true,
  ) async throws -> (Editor, ActionContext) {
    let url = try await VideoFixture.make(red: 10, green: 200, blue: 10, seconds: seconds)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: Double(seconds)),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    try editor.perform(AppendClip(mediaID: media.id))
    let player = Player()
    try await player.load(editor.project)
    await player.seek(toSeconds: playhead)
    var chosen: Media.ID? = choosingMedia ? media.id : nil
    var settings = TimelineSettings()
    var sidePane = SidePane.inspector
    var flag = false
    let context = ActionContext(
      editor: editor,
      player: player,
      settings: Binding(get: { settings }, set: { settings = $0 }),
      mediaSelection: Binding(get: { chosen }, set: { chosen = $0 }),
      sidePane: Binding(get: { sidePane }, set: { sidePane = $0 }),
      isShowingPalette: Binding(get: { flag }, set: { flag = $0 }),
      isImporting: Binding(get: { flag }, set: { flag = $0 }),
    )
    return (editor, context)
  }

}
