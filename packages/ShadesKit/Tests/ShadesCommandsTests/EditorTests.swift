import Foundation
import ShadesCommands
import ShadesCore
import Testing

@MainActor
struct EditorTests {

  // MARK: Internal

  @Test
  func `appending places each clip after the last one`() throws {
    let media = makeMedia(seconds: 2)
    let editor = Editor(project: Project(media: [media]))
    try editor.perform(AppendClip(mediaID: media.id))
    try editor.perform(AppendClip(mediaID: media.id))
    let clips = editor.project.timeline.tracks[0].clips
    #expect(clips.map(\.timelineStart) == [.zero, MediaTime(seconds: 2)])
    #expect(editor.project.timeline.duration == MediaTime(seconds: 4))
  }

  @Test
  func `appending unknown media throws and leaves the project unchanged`() {
    let editor = Editor()
    let before = editor.project
    let missing = UUID()
    #expect(throws: CommandError.mediaNotFound(missing)) {
      try editor.perform(AppendClip(mediaID: missing))
    }
    #expect(editor.project == before)
  }

  @Test
  func `appending to a track that doesn't exist throws`() {
    let media = makeMedia(seconds: 1)
    let editor = Editor(project: Project(media: [media]))
    #expect(throws: CommandError.trackNotFound(index: 3)) {
      try editor.perform(AppendClip(mediaID: media.id, trackIndex: 3))
    }
  }

  @Test
  func `adding the same media twice throws`() throws {
    let media = makeMedia(seconds: 1)
    let editor = Editor()
    try editor.perform(AddMedia(media: media))
    #expect(throws: CommandError.mediaAlreadyAdded(media.id)) {
      try editor.perform(AddMedia(media: media))
    }
    #expect(editor.project.media == [media])
  }

  // MARK: Private

  private func makeMedia(seconds: Double) -> Media {
    Media(
      url: URL(fileURLWithPath: "/tmp/clip.mov"),
      duration: MediaTime(seconds: seconds),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
  }

}
