import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct TransitionTests {

  // MARK: Internal

  @Test
  func `a transition joins touching clips and can be taken off again`() throws {
    var (project, ids) = try twoClips()
    try SetTransition(clipID: ids[1], kind: .dissolve, duration: seconds(1)).apply(to: &project)
    let track = project.timeline.tracks[0]
    #expect(track.transitions.count == 1)
    #expect(track.transitions.first?.outgoing.id == ids[0])
    #expect(track.clips[1].transitionIn == Transition(kind: .dissolve, duration: seconds(1)))
    try SetTransition(clipID: ids[1], kind: nil).apply(to: &project)
    #expect(project.timeline.tracks[0].transitions.isEmpty)
  }

  @Test
  func `transitions need a touching clip before and fit the shorter clip`() throws {
    var (project, ids) = try twoClips()
    #expect(throws: CommandError.self) {
      try SetTransition(clipID: ids[0], kind: .whip).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetTransition(clipID: ids[1], kind: .whip, duration: seconds(9)).apply(to: &project)
    }
  }

  @Test
  func `splitting keeps the transition at the clip's start, not at the split`() throws {
    var (project, ids) = try twoClips()
    try SetTransition(clipID: ids[1], kind: .push).apply(to: &project)
    try SplitClip(clipID: ids[1], at: seconds(4)).apply(to: &project)
    #expect(project.timeline.tracks[0].transitions.count == 1)
    #expect(project.timeline.tracks[0].clips.last?.transitionIn == nil)
  }

  // MARK: Private

  /// Two 3-second clips back to back on V1.
  private func twoClips() throws -> (Project, [Clip.ID]) {
    let media = makeMedia(seconds: 3)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try AppendClip(mediaID: media.id).apply(to: &project)
    return (project, project.timeline.tracks[0].clips.map(\.id))
  }

}
