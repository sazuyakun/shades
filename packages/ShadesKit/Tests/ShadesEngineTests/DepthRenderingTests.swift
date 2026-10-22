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
    let red = try await background()
    let png = try await discFrame(backgroundLayer(of: red), media: red)
    let corner = try PixelProbe.color(of: png, x: 0.05, y: 0.5)
    #expect(corner.red > 180 && corner.green < 80, "the background is the red layer")
    #expect(try GoldenFrame.matches(png, named: "red-replaces-background", in: golden))
  }

  @Test
  func `a cut-out's choke pulls its edge in and pushes it out, and feather softens it`(
  ) async throws {
    let plain = try await edgeOfSubject(CutoutEdge())
    let pushed = try await edgeOfSubject(CutoutEdge(choke: -0.03))
    let pulled = try await edgeOfSubject(CutoutEdge(choke: 0.03))
    #expect(pushed > plain + 0.015, "pushed out, the background starts further from the middle")
    #expect(pulled < plain - 0.015, "pulled in, it starts nearer")
    let red = try await background()
    let refined = try await discFrame(
      backgroundLayer(of: red),
      media: red,
      edge: CutoutEdge(feather: 0.02, choke: -0.01, smoothing: 0.5),
    )
    #expect(try GoldenFrame.matches(refined, named: "red-replaces-background-refined", in: golden))
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

  /// A red video to replace the background with.
  private func background() async throws -> Media {
    try await Media(
      url: VideoFixture.make(red: 220, green: 30, blue: 40, width: 640, height: 360),
      duration: MediaTime(seconds: 1),
      width: 640,
      height: 360,
      hasAudio: false,
    )
  }

  /// A video track with `media` replacing the background.
  private func backgroundLayer(of media: Media) -> Track {
    var canvas = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    canvas.depth = .replaceBackground
    return Track(kind: .video, clips: [canvas])
  }

  /// How far right of the middle the red background starts, along the disc's middle, with the
  /// disc's cut-out edge refined by `edge`.
  private func edgeOfSubject(_ edge: CutoutEdge) async throws -> Double {
    let red = try await background()
    let png = try await discFrame(backgroundLayer(of: red), media: red, edge: edge)
    for step in 0 ... 60 {
      let x = 0.55 + Double(step) * 0.005
      let color = try PixelProbe.color(of: png, x: x, y: 0.5)
      if color.red > 180, color.green < 80 {
        return x
      }
    }
    return 1
  }

  /// The disc video on V1 with its cut-out refined by `edge`, `layer` above it (with its
  /// `media`), rendered.
  private func discFrame(
    _ layer: Track,
    media extra: Media? = nil,
    edge: CutoutEdge = .none,
  ) async throws -> Data {
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
      cutoutEdge: edge,
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
