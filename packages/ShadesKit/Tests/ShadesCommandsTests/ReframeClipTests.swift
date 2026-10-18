import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct ReframeClipTests {

  // MARK: Internal

  @Test
  func `16:9 footage fills the 4:3 frame and follows the subject sideways`() throws {
    var project = try oneClip()
    let clip = try #require(project.timeline.allClips.first)
    try ReframeClip(clipID: clip.id, centerX: 0.6).apply(to: &project)
    let transform = try #require(project.timeline.allClips.first?.transform)
    #expect(abs(transform.scale - 4.0 / 3.0) < 0.001)
    #expect(abs(transform.x - -0.1333) < 0.001)
    #expect(transform.y == 0)
  }

  @Test
  func `a subject at the edge stops where the picture's edge would show`() throws {
    var project = try oneClip()
    let clip = try #require(project.timeline.allClips.first)
    try ReframeClip(clipID: clip.id, centerX: 1).apply(to: &project)
    let transform = try #require(project.timeline.allClips.first?.transform)
    #expect(abs(transform.x - -1.0 / 6.0) < 0.001)
  }

  @Test
  func `text can't be reframed`() throws {
    var project = Project()
    try AddText(text: "hi", at: .zero, duration: MediaTime(seconds: 1)).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(throws: CommandError.self) { try ReframeClip(clipID: clip.id).apply(to: &project) }
  }

  // MARK: Private

  private func oneClip() throws -> Project {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    return project
  }

}
