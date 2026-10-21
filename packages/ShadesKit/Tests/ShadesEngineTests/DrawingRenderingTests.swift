import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Hand-drawn lines: boil, write-on, erase-off, and how they look over video.
struct DrawingRenderingTests {

  // MARK: Internal

  @Test
  func `boiling lines change wobble at their own rate and hold between`() {
    let drawing = Drawing(strokes: [line], boil: 12)
    let first = DrawingRenderer.moment(of: drawing, at: 0.01, duration: 2)
    #expect(DrawingRenderer.moment(of: drawing, at: 0.07, duration: 2) == first)
    #expect(DrawingRenderer.moment(of: drawing, at: 0.09, duration: 2) != first)
    let still = Drawing(strokes: [line], boil: 0)
    #expect(
      DrawingRenderer.moment(of: still, at: 0.01, duration: 2)
        == DrawingRenderer.moment(of: still, at: 2, duration: 2)
    )
  }

  @Test
  func `lines draw themselves on over their write-on time`() async throws {
    let drawing = Drawing(strokes: [line], width: 0.02, boil: 0, writeOn: 1)
    #expect(DrawingRenderer.moment(of: drawing, at: 0.5, duration: 2).drawn == 500)
    let half = try await frame(drawing, at: 0.5)
    #expect(try PixelProbe.color(of: half, x: 0.3, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: half, x: 0.8, y: 0.5).red < 60)
    let whole = try await frame(drawing, at: 1.5)
    #expect(try PixelProbe.color(of: whole, x: 0.8, y: 0.5).red > 200)
  }

  @Test
  func `lines erase themselves off at the end of the clip, last part first`() async throws {
    let drawing = Drawing(strokes: [line], width: 0.02, boil: 0, eraseOff: 1)
    #expect(DrawingRenderer.moment(of: drawing, at: 0.5, duration: 2).drawn == 1000)
    #expect(DrawingRenderer.moment(of: drawing, at: 1.5, duration: 2).drawn == 500)
    let half = try await frame(drawing, at: 1.5)
    #expect(try PixelProbe.color(of: half, x: 0.3, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: half, x: 0.8, y: 0.5).red < 60)
  }

  @Test
  func `a glowing circle draws over the video`() async throws {
    let circle = (0 ... 48).map { step in
      let angle = Double(step) / 48 * 2 * .pi
      return DrawingPoint(x: 0.5 + 0.25 * cos(angle) * 0.75, y: 0.5 + 0.25 * sin(angle))
    }
    let drawing = Drawing(
      strokes: [circle],
      color: HexColor("#FFD84A") ?? .white,
      width: 0.012,
      glow: 0.8,
      boil: 12,
    )
    let png = try await frame(drawing, at: 0.2)
    #expect(try GoldenFrame.matches(png, named: "drawing-glowing-circle", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A line across the middle, left to right.
  private let line = [DrawingPoint(x: 0.1, y: 0.5), DrawingPoint(x: 0.9, y: 0.5)]

  /// The drawing in red-ish strokes (its colour) over blue video, rendered at `seconds`.
  private func frame(_ drawing: Drawing, at seconds: Double) async throws -> Data {
    var drawing = drawing
    if drawing.color == .white {
      drawing.color = HexColor("#FF0000") ?? .white
    }
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 200, seconds: 2)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 2),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let project = Project(media: [media], timeline: Timeline(format: .half, tracks: [
      Track(kind: .video, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.duration,
        timelineStart: .zero,
      )]),
      Track(kind: .video, clips: [Clip(
        source: .drawing(drawing),
        sourceStart: .zero,
        duration: MediaTime(seconds: 2),
        timelineStart: .zero,
      )]),
    ]))
    return try await FrameRenderer.png(of: project, atSeconds: seconds, maxSide: 320)
  }

}
