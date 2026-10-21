import Foundation
import ShadesCore
import ShadesEngine
import ShadesMatting
import ShadesTestSupport
import Testing

/// Footage smeared along its own motion, from its optical flow.
struct FootageBlurRenderingTests {

  // MARK: Internal

  @Test
  func `footage blur smears a sliding square along its motion`() async throws {
    let footage = try await movingSquare()
    let blurred = try await frame(of: footage, footageBlur: true)
    let sharp = try await frame(of: footage, footageBlur: false)
    #expect(try lit(across: blurred) > lit(across: sharp) + 4)
    #expect(try GoldenFrame.matches(blurred, named: "footage-blur-square", in: golden))
  }

  @Test
  func `a clip without footage blur ignores its flow`() async throws {
    let footage = try await movingSquare()
    let withFlow = try await frame(of: footage, footageBlur: false)
    let withoutFlow = try await frame(of: footage, footageBlur: false, usesFlow: false)
    #expect(withFlow == withoutFlow)
  }

  // MARK: Private

  /// A square sliding across a dark frame, and its optical flow.
  private struct Footage {
    let media: Media
    let flow: URL
  }

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  private func movingSquare() async throws -> Footage {
    let url = try await VideoFixture.makeMovingSquare(seconds: 1)
    let flow = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await FlowMaker.make(from: url, to: flow) { _ in }
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 640,
      height: 360,
      hasAudio: false,
    )
    return Footage(media: media, flow: flow)
  }

  /// How many points along the middle row are lit above the dark background: the square and
  /// whatever's smeared off it.
  private func lit(across png: Data) throws -> Int {
    try (0 ..< 160).count { step in
      try PixelProbe.color(of: png, x: Double(step) / 160, y: 0.5).red > 32
    }
  }

  /// The square at 0.5 s under a long shutter (a whole frame, four times over), so its blur is
  /// plain to see.
  private func frame(of footage: Footage, footageBlur: Bool, usesFlow: Bool = true) async throws
    -> Data
  {
    let clip = Clip(
      mediaID: footage.media.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      motionBlur: 4,
      footageBlur: footageBlur,
    )
    let project = Project(
      media: [footage.media],
      timeline: Timeline(
        format: .half,
        tracks: [Track(kind: .video, clips: [clip])],
        shutterAngle: 360,
      ),
    )
    return try await FrameRenderer.png(
      of: project,
      atSeconds: 0.5,
      maxSide: 320,
      flows: usesFlow ? [footage.media.id: footage.flow] : [:],
    )
  }

}
