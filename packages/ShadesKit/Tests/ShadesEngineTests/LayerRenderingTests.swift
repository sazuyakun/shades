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
    #expect(try color(of: png, x: 0.5, y: 0.5).blue > 200)
    #expect(try color(of: png, x: 0.5, y: 0.2).red > 200)
    #expect(try GoldenFrame.matches(png, named: "v2-half-size-over-v1", in: golden))
  }

  @Test
  func `opacity blends a layer with the one below`() async throws {
    let project = try await twoLayers { $0.opacity = 0.5 }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let center = try color(of: png, x: 0.5, y: 0.5)
    #expect((100 ... 160).contains(center.red))
    #expect((100 ... 160).contains(center.blue))
  }

  @Test
  func `a hidden track isn't drawn`() async throws {
    var project = try await twoLayers { _ in }
    project.timeline.tracks[1].isHidden = true
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try color(of: png, x: 0.5, y: 0.5).red > 200)
  }

  @Test
  func `moving and rotating a clip places it in the frame`() async throws {
    let project = try await twoLayers {
      $0.transform = ClipTransform(x: 0.25, y: 0, scale: 0.5, rotation: 90)
    }
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try color(of: png, x: 0.75, y: 0.5).blue > 200)
    #expect(try color(of: png, x: 0.25, y: 0.5).red > 200)
    #expect(try GoldenFrame.matches(png, named: "v2-moved-rotated", in: golden))
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

  private func color(
    of png: Data,
    x: Double,
    y: Double,
  ) throws -> (red: UInt8, green: UInt8, blue: UInt8) {
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
      data: &pixel,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ))
    let width = Double(image.width)
    let height = Double(image.height)
    // why: CoreGraphics' origin is bottom-left, so the row is counted up from the bottom.
    context.draw(
      image,
      in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height),
    )
    return (pixel[0], pixel[1], pixel[2])
  }

}
