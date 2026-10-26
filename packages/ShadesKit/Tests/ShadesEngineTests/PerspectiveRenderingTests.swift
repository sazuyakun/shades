import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Layers in 3D and the timeline's camera.
struct PerspectiveRenderingTests {

  // MARK: Internal

  @Test
  func `a layer turned to the side shrinks towards the edge that leans away`() async throws {
    let project = try await blueOverRed { clip, _ in
      clip.transform = ClipTransform(scale: 0.6, tiltY: 50)
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let nearEdge = try heightOfBlue(in: png, atX: 0.32)
    let farEdge = try heightOfBlue(in: png, atX: 0.62)
    #expect(nearEdge > farEdge + 0.05, "perspective: the far edge looks shorter")
    #expect(try GoldenFrame.matches(png, named: "layer-turned-in-3d", in: golden))
  }

  @Test
  func `a layer further away looks smaller`() async throws {
    let project = try await blueOverRed { clip, _ in
      clip.transform = ClipTransform(scale: 0.6, depth: -2)
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: png, x: 0.33, y: 0.5).red > 200)
    #expect(try GoldenFrame.matches(png, named: "layer-further-away", in: golden))
  }

  @Test
  func `the 3D camera turns and tilts the whole scene`() async throws {
    let project = try await blueOverRed { clip, timeline in
      clip.transform = ClipTransform(x: 0.15, scale: 0.4, depth: 1)
      timeline.camera = [
        Keyframe(property: .tiltY, time: .zero, value: 25),
        Keyframe(property: .tiltX, time: .zero, value: -10),
        Keyframe(property: .scale, time: .zero, value: 0.8),
      ]
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try GoldenFrame.matches(png, named: "camera-turned", in: golden))
  }

  @Test
  func `the camera zooms the picture but leaves captions where they are`() async throws {
    let project = try await blueOverRed { clip, timeline in
      clip.transform.scale = 0.5
      timeline.camera = [Keyframe(property: .scale, time: .zero, value: 2)]
      timeline.tracks.append(Track(kind: .text, clips: [Clip(
        source: .text(TextContent(text: "Hello")),
        sourceStart: .zero,
        duration: MediaTime(seconds: 1),
        timelineStart: .zero,
      )]))
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.1, y: 0.5).blue > 200, "zoomed to fill")
    let caption = try (40 ..< 60).map { column in
      try PixelProbe.color(of: png, x: Double(column) / 100, y: 0.86)
    }
    #expect(caption.contains { $0.red > 200 && $0.green > 200 }, "the caption stays at the bottom")
    #expect(try GoldenFrame.matches(png, named: "camera-zoomed-under-caption", in: golden))
  }

  @Test
  func `a bent layer curves its sides away, so they look shorter than its middle`() async throws {
    let project = try await blueOverRed { clip, _ in
      clip.transform = ClipTransform(scale: 0.7, bend: 120)
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let middle = try heightOfBlue(in: png, atX: 0.5)
    let side = try heightOfBlue(in: png, atX: 0.25)
    #expect(middle > side + 0.03, "the sides lean away")
    #expect(try PixelProbe.color(of: png, x: 0.17, y: 0.5).red > 200, "and come in")
    #expect(try GoldenFrame.matches(png, named: "layer-bent", in: golden))
  }

  @Test
  func `a layer bending fast blurs as it curls`() async throws {
    let project = try await blueOverRed { clip, _ in
      clip.transform = ClipTransform(scale: 0.7)
      clip.keyframes = [
        Keyframe(property: .bend, time: .zero, value: -240),
        Keyframe(property: .bend, time: MediaTime(seconds: 1), value: 240),
      ]
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try GoldenFrame.matches(png, named: "layer-bending-blurred", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A blue clip on V2 over a red one on V1, each edited before rendering.
  private func blueOverRed(
    _ change: (inout Clip, inout Timeline) -> Void
  ) async throws -> Project {
    let red = try await media(FixtureColor(red: 255, green: 0, blue: 0))
    let blue = try await media(FixtureColor(red: 0, green: 0, blue: 255))
    var top = clip(of: blue)
    var timeline = Timeline(format: .half, tracks: [Track(kind: .video, clips: [clip(of: red)])])
    change(&top, &timeline)
    timeline.tracks.insert(Track(kind: .video, clips: [top]), at: 1)
    return Project(media: [red, blue], timeline: timeline)
  }

  private func media(_ color: FixtureColor) async throws -> Media {
    let url = try await VideoFixture.make(left: color, right: color, width: 320, height: 240)
    return Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 240,
      hasAudio: false,
    )
  }

  private func clip(of media: Media) -> Clip {
    Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero)
  }

  /// How much of the column at `x` (fraction of the width) is blue, as a fraction of the height.
  private func heightOfBlue(in png: Data, atX x: Double) throws -> Double {
    let rows = try stride(from: 0.0, through: 1, by: 0.01).filter { y in
      try PixelProbe.color(of: png, x: x, y: y).blue > 200
    }
    return Double(rows.count) / 100
  }

}
