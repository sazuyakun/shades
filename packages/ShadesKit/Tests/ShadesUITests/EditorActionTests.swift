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
  func `⌥F freezes the frame at the playhead and ⇧N puts speed back to normal`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 1)
    try EditorAction.freezeFrame.perform(in: context)
    let clips = editor.project.timeline.tracks[0].clips
    #expect(clips.count == 4 && clips[1].isFrozen)
    #expect(editor.project.timeline.duration == MediaTime(seconds: 6))
    let last = try #require(clips.last)
    try editor.perform(SetClip(clipID: last.id, speed: 2))
    editor.selection = [last.id]
    try EditorAction.normalSpeed.perform(in: context)
    #expect(editor.project.timeline.clip(withID: last.id)?.speed == 1)
    #expect(editor.project.timeline.duration == MediaTime(seconds: 6))
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

  @Test
  func `I and O mark the hovered media and appending places just that part`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    let media = try #require(editor.project.media.first)
    context.hover.wrappedValue = MediaHover(mediaID: media.id, time: MediaTime(seconds: 0.5))
    try EditorAction.markIn.perform(in: context)
    context.hover.wrappedValue = MediaHover(mediaID: media.id, time: MediaTime(seconds: 1.5))
    try EditorAction.markOut.perform(in: context)
    try EditorAction.append.perform(in: context)
    let placed = try #require(editor.project.timeline.tracks[0].clips.last)
    #expect(placed.sourceStart == MediaTime(seconds: 0.5))
    #expect(placed.duration == MediaTime(seconds: 1))
  }

  @Test
  func `marking a short covers the selected clips and picks it`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    #expect(throws: CommandError.self) { try EditorAction.markShort.perform(in: context) }
    let last = try #require(editor.project.timeline.tracks[0].clips.last)
    editor.selection = [last.id]
    try EditorAction.markShort.perform(in: context)
    let short = try #require(editor.project.timeline.shorts.first)
    #expect(short.name == "Short 1")
    #expect(short.range == TimeRange(start: last.timelineStart, end: last.timelineEnd))
    #expect(context.settings.wrappedValue.selectedShort == short.id)
    try EditorAction.renameShort.perform(in: context)
    #expect(context.renamingShort.wrappedValue == short.id)
  }

  @Test
  func `the short under the playhead moves its ends to the playhead and can be removed`()
    async throws
  {
    let (editor, context) = try await editing(seconds: 2, playhead: 1)
    try editor.perform(AddShort(name: "Short 1", start: .zero, end: MediaTime(seconds: 3)))
    try EditorAction.shortStartToPlayhead.perform(in: context)
    #expect(editor.project.timeline.shorts.first?.range.start == MediaTime(seconds: 1))
    await context.player.seek(toSeconds: 2)
    try EditorAction.shortEndToPlayhead.perform(in: context)
    #expect(editor.project.timeline.shorts.first?.range.end == MediaTime(seconds: 2))
    await context.player.seek(toSeconds: 1.5)
    try EditorAction.removeShort.perform(in: context)
    #expect(editor.project.timeline.shorts.isEmpty)
    #expect(throws: CommandError.self) { try EditorAction.removeShort.perform(in: context) }
  }

  @Test
  func `adding text places a title at the playhead and selects it`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 1)
    try EditorAction.addText.perform(in: context)
    let text = try #require(editor.project.timeline.allClips.first { $0.text != nil })
    #expect(text.timelineStart == MediaTime(seconds: 1))
    #expect(text.text?.style.anchor == .center)
    #expect(editor.selection == [text.id])
  }

  @Test
  func `an adjustment clip covers the selected clips`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    editor.selection = Set(editor.project.timeline.tracks[0].clips.map(\.id))
    try EditorAction.addAdjustment.perform(in: context)
    let adjustment = try #require(editor.project.timeline.allClips.first {
      $0.source == .adjustment
    })
    #expect(adjustment.timelineStart == .zero)
    #expect(adjustment.duration == MediaTime(seconds: 4))
  }

  @Test
  func `a dissolve goes only on a clip that follows another`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 0)
    let clips = editor.project.timeline.tracks[0].clips
    editor.selection = [clips[0].id]
    #expect(throws: CommandError.self) { try EditorAction.addTransition.perform(in: context) }
    editor.selection = [clips[1].id]
    try EditorAction.addTransition.perform(in: context)
    #expect(editor.project.timeline.clip(withID: clips[1].id)?.transitionIn?.kind == .dissolve)
  }

  @Test
  func `removing a marker takes the one at the playhead`() async throws {
    let (editor, context) = try await editing(seconds: 2, playhead: 1)
    #expect(throws: CommandError.self) { try EditorAction.removeMarker.perform(in: context) }
    try EditorAction.addMarker.perform(in: context)
    try EditorAction.removeMarker.perform(in: context)
    #expect(editor.project.timeline.markers.isEmpty)
  }

  @Test
  func `the track and draw tools turn each other off`() async throws {
    let (_, context) = try await editing(seconds: 2, playhead: 0)
    try EditorAction.drawTool.perform(in: context)
    try EditorAction.trackTool.perform(in: context)
    #expect(context.settings.wrappedValue.isTracking)
    #expect(!context.settings.wrappedValue.isDrawing)
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
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
    )
    let editor = workspace.editor
    editor.load(Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    try editor.perform(AppendClip(mediaID: media.id))
    let player = workspace.player
    try await player.load(editor.project)
    await player.seek(toSeconds: playhead)
    var chosen: Media.ID? = choosingMedia ? media.id : nil
    var settings = TimelineSettings()
    var sidePane = SidePane.inspector
    var flag = false
    var marks = [Media.ID: SourceMarks]()
    var hover: MediaHover?
    var renaming: Short.ID?
    let context = ActionContext(
      editor: editor,
      player: player,
      workspace: workspace,
      settings: Binding(get: { settings }, set: { settings = $0 }),
      mediaSelection: Binding(get: { chosen }, set: { chosen = $0 }),
      sidePane: Binding(get: { sidePane }, set: { sidePane = $0 }),
      isShowingPalette: Binding(get: { flag }, set: { flag = $0 }),
      isImporting: Binding(get: { flag }, set: { flag = $0 }),
      marks: Binding(get: { marks }, set: { marks = $0 }),
      hover: Binding(get: { hover }, set: { hover = $0 }),
      renamingShort: Binding(get: { renaming }, set: { renaming = $0 }),
    )
    return (editor, context)
  }

}
