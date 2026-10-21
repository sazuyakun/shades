import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct MaskTests {

  // MARK: Internal

  @Test
  func `set_mask adds masks, changes one by index and removes it`() throws {
    var (project, id) = try oneClip()
    try SetMask(clipID: id, shape: .rectangle, width: 0.3).apply(to: &project)
    try SetMask(clipID: id, feather: 0.1, mode: .subtract).apply(to: &project)
    try SetMask(clipID: id, index: 0, x: 0.2, inverted: true).apply(to: &project)
    var masks = try #require(project.timeline.clip(withID: id)?.masks)
    #expect(masks.count == 2)
    #expect(masks[0] == LayerMask(shape: .rectangle, x: 0.2, width: 0.3, inverted: true))
    #expect(masks[1] == LayerMask(feather: 0.1, mode: .subtract))
    try SetMask(clipID: id, index: 0, remove: true).apply(to: &project)
    masks = try #require(project.timeline.clip(withID: id)?.masks)
    #expect(masks == [LayerMask(feather: 0.1, mode: .subtract)])
  }

  @Test
  func `svg path data becomes a path mask's outline inside its box`() throws {
    var (project, id) = try oneClip()
    try SetMask(clipID: id, svgPath: "M0 0 L1 0 L0.5 1 Z").apply(to: &project)
    let mask = try #require(project.timeline.clip(withID: id)?.masks.first)
    #expect(mask.shape == .path)
    #expect(mask.points.first == DrawingPoint(x: 0, y: 0))
    #expect(mask.points.contains(DrawingPoint(x: 0.5, y: 1)))
    #expect(throws: CommandError.self) {
      try SetMask(clipID: id, points: [DrawingPoint(x: 0, y: 0)]).apply(to: &project)
    }
  }

  @Test
  func `masks out of range, past the limit or on sound are refused`() throws {
    var (project, id) = try oneClip()
    #expect(throws: CommandError.self) { try SetMask(clipID: id, index: 0).apply(to: &project) }
    #expect(throws: CommandError.self) {
      try SetMask(clipID: id, width: 0).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetMask(clipID: id, feather: 2).apply(to: &project)
    }
    for _ in 0 ..< SetMask.maskLimit {
      try SetMask(clipID: id).apply(to: &project)
    }
    #expect(throws: CommandError.self) { try SetMask(clipID: id).apply(to: &project) }
    let sound = makeMedia(seconds: 2, hasVideo: false)
    project.media.append(sound)
    try AppendClip(mediaID: sound.id).apply(to: &project)
    let soundID = try #require(project.timeline.allClips.first { $0.mediaID == sound.id }?.id)
    #expect(throws: CommandError.self) { try SetMask(clipID: soundID).apply(to: &project) }
  }

  @Test
  func `at keyframes a mask's box at that moment, in the clip's source time`() throws {
    var (project, id) = try oneClip()
    try SetMask(clipID: id, shape: .ellipse).apply(to: &project)
    try SetMask(clipID: id, index: 0, x: 0.2, at: seconds(1)).apply(to: &project)
    try SetMask(clipID: id, index: 0, x: 0.8, at: seconds(3), easing: .hold).apply(to: &project)
    let mask = try #require(project.timeline.clip(withID: id)?.masks.first)
    #expect(mask.keyframes.map(\.time) == [seconds(1), seconds(3)])
    #expect(abs(mask.placed(at: seconds(2)).x - 0.5) < 0.0001)
    #expect(mask.placed(at: seconds(2)).width == 0.5)
    try SetMask(clipID: id, index: 0, clearKeyframes: true).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.masks.first?.keyframes.isEmpty == true)
    #expect(throws: CommandError.self) {
      try SetMask(clipID: id, index: 0, x: 0.2, at: seconds(9)).apply(to: &project)
    }
  }

  @Test
  func `set_window places and keyframes the grade's window`() throws {
    var (project, id) = try oneClip()
    try SetWindow(clipID: id, shape: .rectangle, x: 0.3, softness: 0.4).apply(to: &project)
    try SetWindow(clipID: id, x: 0.7, at: seconds(2)).apply(to: &project)
    let window = try #require(project.timeline.clip(withID: id)?.grade?.window)
    #expect(!window.isEllipse && window.softness == 0.4 && window.x == 0.3)
    #expect(window.keyframes.map(\.x) == [0.7])
    #expect(throws: CommandError.self) {
      try SetWindow(clipID: id, shape: .path).apply(to: &project)
    }
    try SetWindow(clipID: id, remove: true).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.grade?.window == nil)
  }

  @Test
  func `a mask follows a path through its clip's picture, keeping its offset`() throws {
    var (project, id) = try oneClip()
    try SetMask(clipID: id, x: 0.6, y: 0.4, width: 0.2).apply(to: &project)
    try FollowShape(clipID: id, shape: .mask(0), path: [
      SubjectPoint(time: seconds(0), x: 0.5, y: 0.5),
      SubjectPoint(time: seconds(1), x: 0.7, y: 0.5),
    ]).apply(to: &project)
    let mask = try #require(project.timeline.clip(withID: id)?.masks.first)
    #expect(abs(mask.placed(at: seconds(1)).x - 0.8) < 0.0001)
    #expect(abs(mask.placed(at: seconds(1)).y - 0.4) < 0.0001)
    #expect(mask.placed(at: seconds(1)).width == 0.2)
    #expect(throws: CommandError.self) {
      try FollowShape(clipID: id, shape: .mask(3), path: [
        SubjectPoint(time: seconds(0), x: 0.5, y: 0.5)
      ]).apply(to: &project)
    }
  }

  @Test
  func `a window follows a path through the frame, where the zoomed picture puts it`() throws {
    var (project, id) = try oneClip()
    try SetClip(clipID: id, scale: 2).apply(to: &project)
    try SetWindow(clipID: id).apply(to: &project)
    try FollowShape(clipID: id, shape: .window, path: [
      SubjectPoint(time: seconds(0), x: 0.5, y: 0.5),
      SubjectPoint(time: seconds(1), x: 0.6, y: 0.5),
    ]).apply(to: &project)
    let window = try #require(project.timeline.clip(withID: id)?.grade?.window)
    #expect(abs(window.placed(at: seconds(1)).x - 0.7) < 0.0001)
  }

  // MARK: Private

  /// A 4-second 4:3 video clip on V1.
  private func oneClip() throws -> (Project, Clip.ID) {
    let video = Media(
      url: URL(filePath: "/tmp/clip.mov"),
      duration: seconds(4),
      width: 1440,
      height: 1080,
      hasAudio: false,
    )
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return try (project, #require(project.timeline.allClips.first?.id))
  }

}
