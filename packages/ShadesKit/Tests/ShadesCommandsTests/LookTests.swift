import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct LookTests {

  // MARK: Internal

  @Test
  func `a look sets grade, effects and blend, keeping what it leaves out`() throws {
    var (project, id) = try oneClip()
    try SetLook(clipIDs: [id], grade: Grade(exposure: 0.5), blend: .screen).apply(to: &project)
    try SetLook(clipIDs: [id], effects: Effects(grain: 0.3)).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: id))
    #expect(clip.grade?.exposure == 0.5)
    #expect(clip.effects?.grain == 0.3)
    #expect(clip.blend == .screen)
    try SetLook(clipIDs: [id], clear: true).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.grade == nil)
    #expect(project.timeline.clip(withID: id)?.blend == .screen)
  }

  @Test
  func `grades outside their range and text grades are refused`() throws {
    var (project, id) = try oneClip()
    #expect(throws: CommandError.self) {
      try SetLook(clipIDs: [id], grade: Grade(saturation: 9)).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetLook(clipIDs: [id], effects: Effects(vignette: 2)).apply(to: &project)
    }
    try AddText(text: "hi", at: .zero, duration: seconds(1)).apply(to: &project)
    let text = try #require(project.timeline.allClips.first { $0.text != nil }?.id)
    #expect(throws: CommandError.self) {
      try SetLook(clipIDs: [text], grade: Grade(exposure: 1)).apply(to: &project)
    }
  }

  @Test
  func `adjustments go on top, sharing a track only with other adjustments`() throws {
    var (project, _) = try oneClip()
    try AddAdjustment(at: .zero, duration: seconds(2), effects: Effects(grain: 0.5))
      .apply(to: &project)
    try AddAdjustment(at: seconds(3), duration: seconds(1)).apply(to: &project)
    let videos = project.timeline.tracks.filter { $0.kind == .video }
    #expect(videos.count == 2)
    #expect(videos.last?.clips.map(\.source) == [.adjustment, .adjustment])
    #expect(videos.last?.clips.first?.effects?.grain == 0.5)
  }

  @Test
  func `set_look takes a curve for each colour`() throws {
    let schema = SetLook.parameters["properties"]?["grade"]?["properties"]?["curves"]
    for channel in ["master", "red", "green", "blue"] {
      #expect(schema?["properties"]?[channel] != nil, "no \(channel) curve")
    }
    let command = try CommandRegistry.command(named: "set_look", arguments: [
      "clip_ids": [.string(UUID().uuidString)],
      "grade": ["curves": ["red": [[0, 0], [0.5, 0.6], [1, 1]]]],
    ])
    let look = try #require(command as? SetLook)
    #expect(look.grade?.curves?.red?[1] == DrawingPoint(x: 0.5, y: 0.6))
  }

  // MARK: Private

  private func oneClip() throws -> (Project, Clip.ID) {
    let media = makeMedia(seconds: 5)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    return (project, try #require(project.timeline.allClips.first?.id))
  }

}
