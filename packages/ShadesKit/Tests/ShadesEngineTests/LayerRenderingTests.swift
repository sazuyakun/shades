import AVFoundation
import Foundation
import ImageIO
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Several tracks drawn as layers: order, position, opacity and hidden tracks.
struct LayerRenderingTests {

  // MARK: Internal

  @Test
  func `a smaller clip on V2 is drawn over V1`() async throws {
    let project = try await twoLayers { $0.transform.scale = 0.5 }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.2).red > 200)
    #expect(try GoldenFrame.matches(png, named: "v2-half-size-over-v1", in: golden))
  }

  @Test
  func `opacity blends a layer with the one below`() async throws {
    let project = try await twoLayers { $0.opacity = 0.5 }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let center = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    #expect((100 ... 160).contains(center.red))
    #expect((100 ... 160).contains(center.blue))
  }

  @Test
  func `a hidden track isn't drawn`() async throws {
    var project = try await twoLayers { _ in }
    project.timeline.tracks[1].isHidden = true
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).red > 200)
  }

  @Test
  func `moving and rotating a clip places it in the frame`() async throws {
    let project = try await twoLayers {
      $0.transform = ClipTransform(x: 0.25, y: 0, scale: 0.5, rotation: 90)
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.75, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: png, x: 0.25, y: 0.5).red > 200)
    #expect(try GoldenFrame.matches(png, named: "v2-moved-rotated", in: golden))
  }

  @Test
  func `a cropped clip shows the layer under it where its edges were cut`() async throws {
    let project = try await twoLayers { $0.crop = Crop(left: 0.25, top: 0.25) }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.6, y: 0.6).blue > 200)
    #expect(try PixelProbe.color(of: png, x: 0.1, y: 0.6).red > 200)
    #expect(try PixelProbe.color(of: png, x: 0.6, y: 0.1).red > 200)
    #expect(try GoldenFrame.matches(png, named: "v2-cropped-top-left", in: golden))
  }

  @Test
  func `keyframes move a clip across the frame over time`() async throws {
    let project = try await twoLayers {
      $0.transform.scale = 0.3
      $0.keyframes = [
        Keyframe(property: .x, time: .zero, value: -0.3),
        Keyframe(property: .x, time: MediaTime(seconds: 0.8), value: 0.3, easing: .easeInOut),
      ]
    }
    let start = try await FrameRenderer.png(of: project, atSeconds: 0, maxSide: 320)
    let end = try await FrameRenderer.png(of: project, atSeconds: 0.9, maxSide: 320)
    #expect(try PixelProbe.color(of: start, x: 0.2, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: start, x: 0.8, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: end, x: 0.8, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: end, x: 0.2, y: 0.5).red > 200)
  }

  @Test
  func `a clip's look doesn't change the playback structure, its timing does`() async throws {
    let project = try await twoLayers { _ in }
    var restyled = project
    restyled.timeline.tracks[1].clips[0].opacity = 0.3
    restyled.timeline.tracks[1].isHidden = true
    var retimed = project
    retimed.timeline.tracks[1].clips[0].timelineStart = MediaTime(seconds: 0.5)
    let structure = Composition.Structure(project.timeline)
    #expect(Composition.Structure(restyled.timeline) == structure)
    #expect(Composition.Structure(retimed.timeline) != structure)
  }

  @Test
  func `a caption is drawn over the video near the bottom`() async throws {
    var project = try await twoLayers { _ in }
    project.timeline.tracks.remove(at: 1)
    let caption = Clip(
      source: .text(TextContent(text: "Hello Shades")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    project.timeline.tracks.append(Track(kind: .text, clips: [caption]))
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.3).red > 200)
    let lowerBand = try (0 ..< 40).flatMap { column in
      try [0.8, 0.84, 0.88]
        .map { row in try PixelProbe.color(of: png, x: 0.3 + Double(column) * 0.01, y: row) }
    }
    // why: downscaled, white letters blend with their outline; red video never has green or blue.
    #expect(lowerBand.contains { $0.green > 150 && $0.blue > 150 })
    #expect(try GoldenFrame.matches(png, named: "caption-over-video", in: golden))
  }

  @Test
  func `editing words doesn't change the playback structure`() {
    let caption = Clip(
      source: .text(TextContent(text: "one")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    let timeline = Timeline(tracks: [Track(kind: .video), Track(kind: .text, clips: [caption])])
    var edited = timeline
    edited.tracks[1].clips[0].source = .text(TextContent(text: "two"))
    #expect(Composition.Structure(edited) == Composition.Structure(timeline))
  }

  @Test
  func `the layer shaders compile`() throws {
    _ = try MetalRenderer()
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// Red full-frame 4:3 video on V1 and blue on V2, with V2's clip adjusted by `style`.
  private func twoLayers(_ style: (inout Clip) -> Void) async throws -> Project {
    let red = try await media(FixtureColor(red: 255, green: 0, blue: 0))
    let blue = try await media(FixtureColor(red: 0, green: 0, blue: 255))
    var top = clip(of: blue)
    style(&top)
    return Project(
      media: [red, blue],
      timeline: Timeline(
        format: .half,
        tracks: [Track(kind: .video, clips: [clip(of: red)]), Track(kind: .video, clips: [top])],
      ),
    )
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

}
