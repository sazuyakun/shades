import CoreGraphics
import Foundation
import ImageIO
import ShadesCore
import ShadesEngine
import ShadesMatting
import ShadesTestSupport
import Testing

/// Depth slots drawn with a real cut-out: text behind the subject disappears where the subject
/// is.
struct DepthRenderingTests {

  // MARK: Internal

  @Test
  func `text behind the subject is hidden by it and shows around it`() async throws {
    let disc = try await VideoFixture.makeDisc(seconds: 1)
    let matte = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await MatteMaker.make(from: disc, to: matte, engine: .visionForeground) { _ in }
    let media = Media(
      url: disc,
      duration: MediaTime(seconds: 1),
      width: 640,
      height: 360,
      hasAudio: false,
    )
    var words = Clip(
      source: .text(TextContent(text: "BEHIND THE SUBJECT")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    words.depth = .behindSubject
    // why: captions sit near the bottom; this moves the line up across the disc's middle.
    words.transform.y = -0.36
    let project = Project(media: [media], timeline: Timeline(format: .half, tracks: [
      Track(
        kind: .video,
        clips: [Clip(
          mediaID: media.id,
          sourceStart: .zero,
          duration: media.duration,
          timelineStart: .zero,
        )],
      ),
      Track(kind: .text, clips: [words]),
    ]))
    let png = try await FrameRenderer.png(
      of: project,
      atSeconds: 0.5,
      maxSide: 640,
      mattes: [media.id: matte],
    )
    let middle = try color(of: png, x: 0.5, y: 0.5)
    #expect(middle.red > 200 && middle.blue < 80, "the disc covers the text")
    #expect(try GoldenFrame.matches(png, named: "text-behind-subject", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

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
    context.draw(
      image,
      in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height),
    )
    return (pixel[0], pixel[1], pixel[2])
  }

}
