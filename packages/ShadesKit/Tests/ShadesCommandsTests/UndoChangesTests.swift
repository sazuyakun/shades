import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct UndoChangesTests {

  // MARK: Internal

  @Test
  func `undoing earlier edits keeps the edits made since`() throws {
    var project = try twoClips()
    let first = try #require(project.timeline.allClips.first)
    let change = try changing(&project) { project in
      try SetClip(clipID: first.id, opacity: 0.5).apply(to: &project)
      try AppendClip(mediaID: first.mediaID ?? UUID()).apply(to: &project)
    }
    let last = try #require(project.timeline.allClips.dropFirst().first)
    try SetClip(clipID: last.id, opacity: 0.25).apply(to: &project)
    try UndoChanges(changes: [change]).apply(to: &project)
    let clips = project.timeline.allClips
    #expect(clips.count == 2)
    #expect(clips.first?.opacity == 1)
    #expect(clips.last?.opacity == 0.25)
  }

  @Test
  func `clips an edit removed come back in place, and the ones it moved move back`() throws {
    var project = try twoClips()
    let first = try #require(project.timeline.allClips.first)
    let change = try changing(&project) { project in
      try DeleteClips(clipIDs: [first.id], ripple: true).apply(to: &project)
    }
    try AddMarker(at: seconds(0.5)).apply(to: &project)
    let rippled = project
    try UndoChanges(changes: [change]).apply(to: &project)
    #expect(project.timeline.allClips.map(\.timelineStart) == [seconds(0), seconds(2)])
    #expect(project.timeline.allClips.first?.id == first.id)
    #expect(project.timeline.markers == rippled.timeline.markers)
  }

  @Test
  func `later edits to the same things stop the undo`() throws {
    var project = try twoClips()
    let first = try #require(project.timeline.allClips.first)
    let change = try changing(&project) { project in
      try SetClip(clipID: first.id, opacity: 0.5).apply(to: &project)
    }
    try SetClip(clipID: first.id, opacity: 0.75).apply(to: &project)
    #expect(throws: CommandError.editedSince) {
      try UndoChanges(changes: [change]).apply(to: &project)
    }
  }

  @Test
  func `bringing back a clip where a later one now sits stops the undo`() throws {
    var project = try twoClips()
    let last = try #require(project.timeline.allClips.last)
    let media = try #require(last.mediaID)
    let change = try changing(&project) { project in
      try DeleteClips(clipIDs: [last.id], ripple: false).apply(to: &project)
    }
    try AppendClip(mediaID: media).apply(to: &project)
    #expect(throws: CommandError.editedSince) {
      try UndoChanges(changes: [change]).apply(to: &project)
    }
  }

  @Test
  func `undoing twice finds nothing left to undo`() throws {
    var project = try twoClips()
    let first = try #require(project.timeline.allClips.first)
    let change = try changing(&project) { project in
      try SetClip(clipID: first.id, opacity: 0.5).apply(to: &project)
    }
    try UndoChanges(changes: [change]).apply(to: &project)
    #expect(throws: CommandError.nothingToUndo) {
      try UndoChanges(changes: [change]).apply(to: &project)
    }
  }

  @Test
  func `a change survives being saved and read back`() throws {
    var project = try twoClips()
    let change = try changing(&project) { project in
      try AddTrack(kind: .video).apply(to: &project)
    }
    let data = try JSONEncoder().encode(change)
    #expect(try JSONDecoder().decode(ProjectChange.self, from: data) == change)
  }

  // MARK: Private

  private func twoClips() throws -> Project {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try AppendClip(mediaID: media.id).apply(to: &project)
    return project
  }

  /// Applies `edit` and returns what it changed.
  private func changing(
    _ project: inout Project,
    edit: (inout Project) throws -> Void,
  ) throws -> ProjectChange {
    let before = project
    try edit(&project)
    return try #require(ProjectChange(from: before, to: project))
  }

}
