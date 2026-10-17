import AVFoundation
import Foundation
import ImageIO
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

@MainActor
struct FrameRendererTests {

  // MARK: Internal

  @Test
  func `a rendered frame shows the clip's color`() async throws {
    let project = try await makeProject(left: .red, right: .red)
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let (red, green, blue) = try pixel(of: png, x: 0.5, y: 0.5)
    #expect(red > 200)
    #expect(green < 60)
    #expect(blue < 60)
  }

  @Test
  func `a gap in the timeline renders black instead of failing`() async throws {
    let project = try await makeProject(left: .red, right: .red, startingAt: MediaTime(seconds: 1))
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let (red, green, blue) = try pixel(of: png, x: 0.5, y: 0.5)
    #expect(red < 20)
    #expect(green < 20)
    #expect(blue < 20)
  }

  @Test
  func `portrait video is drawn upright using its rotation`() async throws {
    // Stored landscape, red left / blue right, tagged "rotate 90° clockwise" like an iPhone.
    // Upright, red must be on top and blue at the bottom.
    let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let project = try await makeProject(left: .red, right: .blue, transform: quarterTurn)
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let top = try pixel(of: png, x: 0.5, y: 0.25)
    let bottom = try pixel(of: png, x: 0.5, y: 0.75)
    #expect(top.0 > 200 && top.2 < 60)
    #expect(bottom.2 > 200 && bottom.0 < 60)
    #expect(try GoldenFrame.matches(png, named: "portrait-upright", in: golden))
  }

  @Test
  func `rotated HEVC video, as an iPhone records it, is drawn upright`() async throws {
    let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let project = try await makeProject(
      left: .red,
      right: .blue,
      transform: quarterTurn,
      codec: .hevc,
    )
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let top = try pixel(of: png, x: 0.5, y: 0.25)
    let bottom = try pixel(of: png, x: 0.5, y: 0.75)
    #expect(top.0 > 200 && top.2 < 60)
    #expect(bottom.2 > 200 && bottom.0 < 60)
  }

  @Test
  func `frames are rendered in the timeline's format, not the clip's`() async throws {
    // A 16:9 clip in a 4:3 timeline: 4:3 output, black bars above and below.
    let project = try await makeProject(left: .red, right: .red)
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let (width, height) = try size(of: png)
    let top = try pixel(of: png, x: 0.5, y: 0.05)
    let center = try pixel(of: png, x: 0.5, y: 0.5)
    #expect(width == 320)
    #expect(height == 240)
    #expect(top.0 < 20)
    #expect(center.0 > 200)
    #expect(try GoldenFrame.matches(png, named: "landscape-in-4x3", in: golden))
  }

  @Test
  func `rendering an empty timeline throws timelineEmpty`() async {
    await #expect(throws: EngineError.timelineEmpty) {
      try await FrameRenderer.png(of: Project(), atSeconds: 0, maxSide: 320)
    }
  }

  // MARK: Private

  /// A project whose timeline is one 1-second 320×180 test clip, placed at `start`. The media's
  /// size is the upright (display) size, as `MediaLoader` reports it.
  /// Reference frames for this suite, checked into the repo.
  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  private func makeProject(
    left: FixtureColor,
    right: FixtureColor,
    transform: CGAffineTransform = .identity,
    codec: AVVideoCodecType = .proRes4444,
    startingAt start: MediaTime = .zero,
  ) async throws -> Project {
    let url = try await VideoFixture.make(
      left: left,
      right: right,
      transform: transform,
      codec: codec,
    )
    let upright = CGSize(width: 320, height: 180).applying(transform)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: Int(abs(upright.width)),
      height: Int(abs(upright.height)),
      hasAudio: false,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: start,
    )
    return Project(
      media: [media],
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [clip])]),
    )
  }

  /// Decodes a PNG and returns its size in pixels.
  private func size(of png: Data) throws -> (width: Int, height: Int) {
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return (image.width, image.height)
  }

  /// Decodes a PNG and returns the RGB at a point given as fractions of its width and height
  /// (0, 0 is the top-left corner).
  private func pixel(of png: Data, x: Double, y: Double) throws -> (UInt8, UInt8, UInt8) {
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
