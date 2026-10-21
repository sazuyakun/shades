import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct TextPathTests {

  // MARK: Internal

  @Test
  func `text follows a path of points and an empty path straightens it`() throws {
    var (project, clip) = try titled()
    let wave = [DrawingPoint(x: 0.1, y: 0.5), DrawingPoint(x: 0.5, y: 0.3), DrawingPoint(
      x: 0.9,
      y: 0.5,
    )]
    try SetText(clipID: clip, path: wave, pathOffset: 0.2).apply(to: &project)
    #expect(project.timeline.clip(withID: clip)?.text?.path == TextPath(points: wave, offset: 0.2))
    try SetText(clipID: clip, text: "new words").apply(to: &project)
    #expect(project.timeline.clip(withID: clip)?.text?.path?.points == wave, "kept")
    try SetText(clipID: clip, path: []).apply(to: &project)
    #expect(project.timeline.clip(withID: clip)?.text?.path == nil)
  }

  @Test
  func `an SVG path is scaled from its view box onto the frame`() throws {
    var (project, clip) = try titled()
    try SetText(clipID: clip, svgPath: "M 0 50 Q 50 0 100 50", viewBox: [100, 100])
      .apply(to: &project)
    let points = try #require(project.timeline.clip(withID: clip)?.text?.path?.points)
    #expect(points.first == DrawingPoint(x: 0, y: 0.5))
    #expect(points.last == DrawingPoint(x: 1, y: 0.5))
    #expect(points.contains { $0.y < 0.3 }, "the curve rises towards its control point")
  }

  @Test
  func `paths need two points and offsets need a path`() throws {
    var (project, clip) = try titled()
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip, path: [DrawingPoint(x: 0, y: 0)]).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip, pathOffset: 0.5).apply(to: &project)
    }
    let travel = SetKeyframes(clipID: clip, keyframes: [
      SetKeyframes.Key(property: .pathOffset, at: .zero, value: -1, easing: nil)
    ])
    #expect(throws: CommandError.self) { try travel.apply(to: &project) }
    try SetText(clipID: clip, path: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 1)])
      .apply(to: &project)
    try travel.apply(to: &project)
    let moving = try #require(project.timeline.clip(withID: clip))
    #expect(moving.value(of: .pathOffset, at: .zero) == -1)
  }

  @Test
  func `spacing is kept in range and the camera can't travel a path`() throws {
    var (project, clip) = try titled()
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip, style: TextStyle(spacing: 5)).apply(to: &project)
    }
    try SetText(clipID: clip, style: TextStyle(spacing: 0.3)).apply(to: &project)
    #expect(project.timeline.clip(withID: clip)?.text?.style.spacing == 0.3)
    #expect(throws: CommandError.self) {
      try SetCamera(keyframes: [
        SetKeyframes.Key(property: .pathOffset, at: .zero, value: 1, easing: nil)
      ]).apply(to: &project)
    }
  }

  // MARK: Private

  /// A project with one 2-second title, and the title's ID.
  private func titled() throws -> (Project, Clip.ID) {
    var project = Project()
    try AddText(text: "along the way", at: .zero, duration: seconds(2)).apply(to: &project)
    return try (project, #require(project.timeline.allClips.first?.id))
  }

}
