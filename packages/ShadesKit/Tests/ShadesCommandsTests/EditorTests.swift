import Foundation
import ShadesCommands
import ShadesCore
import Testing

@MainActor
struct EditorTests {
  @Test
  func `a failed command leaves the project unchanged`() {
    let editor = Editor()
    let before = editor.project
    let missing = UUID()
    #expect(throws: CommandError.mediaNotFound(missing)) {
      try editor.perform(AppendClip(mediaID: missing))
    }
    #expect(editor.project == before)
    #expect(editor.undoTitle == nil)
  }

  @Test
  func `undo and redo step through edits by name`() throws {
    let media = makeMedia(seconds: 2)
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    #expect(editor.undoTitle == "Append Clip")
    try editor.undo()
    #expect(editor.project.timeline.allClips.isEmpty)
    #expect(editor.redoTitle == "Append Clip")
    try editor.redo()
    #expect(editor.project.timeline.allClips.count == 1)
  }

  @Test
  func `a batch is one undo step and all or nothing`() throws {
    let media = makeMedia(seconds: 2)
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(
      [AppendClip(mediaID: media.id), AppendClip(mediaID: media.id)],
      title: "Claude",
    )
    #expect(editor.project.timeline.allClips.count == 2)
    try editor.undo()
    #expect(editor.project.timeline.allClips.isEmpty)
    #expect(throws: CommandError.self) {
      try editor.perform([AppendClip(mediaID: media.id), AppendClip(mediaID: UUID())], title: "x")
    }
    #expect(editor.project.timeline.allClips.isEmpty)
  }

  @Test
  func `a new edit clears redo`() throws {
    let media = makeMedia(seconds: 2)
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    try editor.undo()
    try editor.perform(AppendClip(mediaID: media.id))
    #expect(editor.redoTitle == nil)
    #expect(throws: CommandError.nothingToRedo) { try editor.redo() }
  }

  @Test
  func `selection forgets clips that were deleted`() throws {
    let media = makeMedia(seconds: 2)
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    let clip = try #require(editor.project.timeline.allClips.first)
    editor.selection = [clip.id]
    try editor.perform(DeleteClips(clipIDs: [clip.id]))
    #expect(editor.selection.isEmpty)
  }

  @Test
  func `adding the same media twice throws`() throws {
    let media = makeMedia(seconds: 1)
    let editor = Editor()
    try editor.perform(AddMedia(media: media))
    #expect(throws: CommandError.mediaAlreadyAdded(media.id)) {
      try editor.perform(AddMedia(media: media))
    }
  }
}
