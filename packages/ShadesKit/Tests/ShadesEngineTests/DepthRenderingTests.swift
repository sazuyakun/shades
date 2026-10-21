import CoreGraphics
import Foundation
import ImageIO
import ShadesCore
import ShadesEngine
import ShadesMatting
import ShadesTestSupport
import Testing

/// Depth slots drawn with a real cut-out of an orange disc: layers go behind it, inside it, or
/// replace what's around it.
struct DepthRenderingTests {

  // MARK: Internal

  @Test
  func `text behind the subject is hidden by it and shows around it`() async throws {
    let png = try await discFrame(words("BEHIND THE SUBJECT", in: .behindSubject))
    let middle = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    #expect(middle.red > 200 && middle.blue < 80, "the disc covers the text")
    #expect(try GoldenFrame.matches(png, named: "text-behind-subject", in: golden))
  }

  @Test
  func `text inside the subject shows only within its outline`() async throws {
    let png = try await discFrame(words("INSIDE THE SUBJECT", in: .insideSubject))
    #expect(try GoldenFrame.matches(png, named: "text-inside-subject", in: golden))
  }

  @Test
  func `a layer replacing the background fills around the subject`() async throws {
    let red = try await Media(
      url: VideoFixture.make(red: 220, green: 30, blue: 40, width: 640, height: 360),
      duration: MediaTime(seconds: 1),
      width: 640,
      height: 360,
      hasAudio: false,
    )
    var canvas = Clip(
      mediaID: red.id,
      sourceStart: .zero,
      duration: red.duration,
      timelineStart: .zero,
    )
    canvas.depth = .replaceBackground
    let png = try await discFrame(Track(kind: .video, clips: [canvas]), media: red)
    let corner = try PixelProbe.color(of: png, x: 0.05, y: 0.5)
    #expect(corner.red > 180 && corner.green < 80, "the background is the red layer")
    #expect(try GoldenFrame.matches(png, named: "red-replaces-background", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A text track with `text` in `slot`, its line moved up across the disc's middle.
  private func words(_ text: String, in slot: DepthSlot) -> Track {
    var words = Clip(
      source: .text(TextContent(text: text)),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    words.depth = slot
    // why: captions sit near the bottom; this moves the line up across the disc's middle.
    words.transform.y = -0.36
    return Track(kind: .text, clips: [words])
  }

  /// The disc video on V1 with its cut-out, `layer` above it (with its `media`), rendered.
  private func discFrame(_ layer: Track, media extra: Media? = nil) async throws -> Data {
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
    let footage = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let project = Project(
      media: [media] + [extra].compactMap(\.self),
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [footage]), layer]),
    )
    return try await FrameRenderer.png(
      of: project,
      atSeconds: 0.5,
      maxSide: 640,
      mattes: [media.id: matte],
    )
  }

}
