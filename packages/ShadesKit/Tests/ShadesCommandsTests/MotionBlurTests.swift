import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct MotionBlurTests {

  // MARK: Internal

  @Test
  func `the shutter is set for the whole timeline within 0 to 360 degrees`() throws {
    var project = try oneClip()
    #expect(project.timeline.shutterAngle == 180)
    try SetShutter(angle: 90).apply(to: &project)
    #expect(project.timeline.shutterAngle == 90)
    #expect(throws: CommandError.self) { try SetShutter(angle: 400).apply(to: &project) }
    #expect(project.timeline.shutterAngle == 90)
  }

  @Test
  func `a clip's motion blur scales the shutter and its footage blur switches on`() throws {
    var project = try oneClip()
    let id = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: id, motionBlur: 2, footageBlur: true).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: id))
    #expect(clip.motionBlur == 2)
    #expect(clip.footageBlur)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: id, motionBlur: -1).apply(to: &project)
    }
  }

  @Test
  func `footage blur is refused on a clip that isn't video`() throws {
    var project = try oneClip()
    try AddText(text: "Hi", at: .zero, duration: seconds(2)).apply(to: &project)
    let text = try #require(project.timeline.allClips.first { $0.text != nil }?.id)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: text, footageBlur: true).apply(to: &project)
    }
    try SetClip(clipID: text, motionBlur: 0).apply(to: &project)
    #expect(project.timeline.clip(withID: text)?.motionBlur == 0)
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)

  private func oneClip() throws -> Project {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
