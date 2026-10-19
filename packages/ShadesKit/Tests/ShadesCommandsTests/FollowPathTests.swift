import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct FollowPathTests {

  // MARK: Internal

  @Test
  func `a layer follows a point moving across the picture, keeping its offset`() throws {
    var (project, video, text) = try videoAndText()
    try SetClip(clipID: text, x: 0.1, y: -0.2).apply(to: &project)
    try FollowPath(clipID: text, targetID: video, path: [
      SubjectPoint(time: seconds(0), x: 0.5, y: 0.5),
      SubjectPoint(time: seconds(1), x: 0.75, y: 0.5),
    ]).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: text))
    #expect(abs(clip.value(of: .x, at: seconds(0)) - 0.1) < 0.0001)
    #expect(abs(clip.value(of: .x, at: seconds(1)) - 0.35) < 0.0001)
    #expect(abs(clip.value(of: .y, at: seconds(1)) - -0.2) < 0.0001)
  }

  @Test
  func `the target's zoom and position carry the point with them`() throws {
    var (project, video, text) = try videoAndText()
    try SetClip(clipID: video, x: 0.1, scale: 2).apply(to: &project)
    try FollowPath(clipID: text, targetID: video, path: [
      SubjectPoint(time: seconds(0), x: 0.5, y: 0.5),
      SubjectPoint(time: seconds(1), x: 0.75, y: 0.5),
    ]).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: text))
    #expect(abs(clip.value(of: .x, at: seconds(1)) - 0.5) < 0.0001)
  }

  @Test
  func `16:9 footage is fitted inside the 4:3 frame before following`() throws {
    var (project, video, text) = try videoAndText(width: 1920, height: 1080)
    try FollowPath(clipID: text, targetID: video, path: [
      SubjectPoint(time: seconds(0), x: 0.5, y: 0.5),
      SubjectPoint(time: seconds(1), x: 0.5, y: 1),
    ]).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: text))
    #expect(abs(clip.value(of: .y, at: seconds(1)) - 0.375) < 0.0001)
  }

  @Test
  func `a path outside the time both clips show is refused`() throws {
    var (project, video, text) = try videoAndText()
    #expect(throws: CommandError.self) {
      try FollowPath(clipID: text, targetID: video, path: [
        SubjectPoint(time: seconds(5), x: 0.5, y: 0.5)
      ]).apply(to: &project)
    }
  }

  // MARK: Private

  /// A 2-second 4:3 video clip with a text clip over it.
  private func videoAndText(
    width: Int = 1440,
    height: Int = 1080,
  ) throws -> (Project, Clip.ID, Clip.ID) {
    let media = Media(
      url: URL(filePath: "/tmp/clip.mov"),
      duration: seconds(2),
      width: width,
      height: height,
      hasAudio: false,
    )
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try AddText(text: "hi", at: .zero, duration: seconds(2)).apply(to: &project)
    let video = try #require(project.timeline.tracks.first { $0.kind == .video }?.clips.first?.id)
    let text = try #require(project.timeline.tracks.first { $0.kind == .text }?.clips.first?.id)
    return (project, video, text)
  }

}
