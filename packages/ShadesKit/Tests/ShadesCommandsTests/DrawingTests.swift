import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct DrawingTests {

  // MARK: Internal

  @Test
  func `a drawing goes on a free track above the footage with its look`() throws {
    var project = try footage()
    try AddDrawing(
      at: seconds(1),
      strokes: [[DrawingPoint(x: 0.2, y: 0.2), DrawingPoint(x: 0.8, y: 0.3)]],
      color: HexColor("#FF3B30"),
      glow: 0.5,
      writeOn: 0.8,
    ).apply(to: &project)
    let track = try #require(project.timeline.tracks.filter { $0.kind == .video }.last)
    #expect(project.timeline.label(of: track) == "V2")
    let drawing = try #require(track.clips.first?.drawing)
    #expect(drawing.color == HexColor("#FF3B30"))
    #expect(drawing.boil == 12)
    #expect(drawing.writeOn == 0.8)
    #expect(track.clips.first?.duration == seconds(3))
  }

  @Test
  func `svg path data becomes strokes scaled to the frame`() throws {
    var project = try footage()
    try AddDrawing(
      at: .zero,
      svgPath: "M10 10 L90 10 l0 80 Z M 20,50 q30-40 60,0",
      viewBox: [100, 100],
    ).apply(to: &project)
    let drawing = try #require(project.timeline.allClips.compactMap(\.drawing).first)
    #expect(drawing.strokes.count == 2)
    #expect(drawing.strokes[0].map(\.x) == [0.1, 0.9, 0.9, 0.1])
    #expect(drawing.strokes[0].last?.y == 0.1)
    #expect(drawing.strokes[1].count == 17)
    #expect(abs((drawing.strokes[1].last?.x ?? 0) - 0.8) < 0.0001)
  }

  @Test
  func `strokes can be added and the look changed, within limits`() throws {
    var project = try footage()
    try AddDrawing(at: .zero, strokes: [[DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 1)]])
      .apply(to: &project)
    let id = try #require(project.timeline.allClips.first { $0.drawing != nil }?.id)
    try SetDrawing(
      clipID: id,
      addStrokes: [[DrawingPoint(x: 1, y: 0), DrawingPoint(x: 0, y: 1)]],
      boil: 0,
    ).apply(to: &project)
    let drawing = try #require(project.timeline.clip(withID: id)?.drawing)
    #expect(drawing.strokes.count == 2)
    #expect(drawing.boil == 0)
    #expect(throws: CommandError.self) { try SetDrawing(clipID: id, glow: 3).apply(to: &project) }
    #expect(throws: CommandError.self) {
      try AddDrawing(at: .zero, svgPath: "M 0 0 A 1 1 0 0 0 5 5").apply(to: &project)
    }
  }

  // MARK: Private

  private func footage() throws -> Project {
    let video = makeMedia(seconds: 10)
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
