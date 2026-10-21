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

  @Test
  func `panning follows a subject walking across, eased and never faster than the top speed`()
    throws
  {
    var project = try oneClip(seconds: 10)
    let clip = try #require(project.timeline.allClips.first)
    let walk = stride(from: 0.0, through: 10, by: 0.5).map { time in
      SubjectPoint(time: seconds(time), x: 0.3 + 0.4 * time / 10, y: 0.5)
    }
    try PanToSubject(clipID: clip.id, path: walk).apply(to: &project)
    let panned = try #require(project.timeline.allClips.first)
    let moves = panned.keyframes.filter { $0.property == .x }
    let first = try #require(moves.first)
    let last = try #require(moves.last)
    #expect(panned.keyframes.allSatisfy { $0.property == .x })
    #expect(first.value > last.value)
    #expect(zip(moves, moves.dropFirst()).allSatisfy { $0.value >= $1.value })
    #expect(moves.allSatisfy { abs($0.value) <= 1.0 / 6.0 + 0.0001 })
    for (from, to) in zip(moves, moves.dropFirst()) {
      let speed = abs(to.value - from.value) / (to.time - from.time).seconds
      #expect(speed <= PanToSubject.topSpeed + 0.001)
    }
    let start = panned.value(of: .x, at: seconds(0.5)) - panned.value(of: .x, at: .zero)
    let middle = panned.value(of: .x, at: seconds(5.5)) - panned.value(of: .x, at: seconds(5))
    #expect(abs(start) < abs(middle))
  }

  @Test
  func `a subject jittering in place keeps the camera still`() throws {
    var project = try oneClip(seconds: 6)
    let clip = try #require(project.timeline.allClips.first)
    let jitter = stride(from: 0.0, through: 6, by: 0.5).enumerated().map { index, time in
      SubjectPoint(time: seconds(time), x: index.isMultiple(of: 2) ? 0.61 : 0.59, y: 0.5)
    }
    try PanToSubject(clipID: clip.id, path: jitter).apply(to: &project)
    let moves = try #require(project.timeline.allClips.first?.keyframes)
    #expect(moves.count == 2)
    #expect(Set(moves.map(\.value)).count == 1)
  }

  @Test
  func `a locked reframe drops the pan`() throws {
    var project = try oneClip(seconds: 4)
    let clip = try #require(project.timeline.allClips.first)
    let walk = [SubjectPoint(time: .zero, x: 0.2, y: 0.5), .init(time: seconds(4), x: 0.8, y: 0.5)]
    try PanToSubject(clipID: clip.id, path: walk).apply(to: &project)
    try ReframeClip(clipID: clip.id, centerX: 0.5).apply(to: &project)
    let locked = try #require(project.timeline.allClips.first)
    #expect(locked.keyframes.isEmpty)
    #expect(locked.transform.x == 0)
  }

  @Test
  func `panning needs the subject's path over the clip`() throws {
    var project = try oneClip(seconds: 2)
    let clip = try #require(project.timeline.allClips.first)
    let later = [SubjectPoint(time: seconds(5), x: 0.5, y: 0.5)]
    #expect(throws: CommandError.self) {
      try PanToSubject(clipID: clip.id, path: later).apply(to: &project)
    }
  }

  // MARK: Private

  private func oneClip(seconds: Double = 2) throws -> Project {
    let media = makeMedia(seconds: seconds)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    return project
  }

}
