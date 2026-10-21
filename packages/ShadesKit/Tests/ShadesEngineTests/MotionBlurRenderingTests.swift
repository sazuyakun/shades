import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Moving layers blurred across the shutter.
struct MotionBlurRenderingTests {

  // MARK: Internal

  @Test
  func `a sliding sticker smears along its path`() async throws {
    let blurred = try await slidingSticker(shutter: 180)
    let sharp = try await slidingSticker(shutter: 0)
    #expect(try smear(across: blurred) > smear(across: sharp) + 6)
    #expect(try GoldenFrame.matches(blurred, named: "sticker-sliding-blur", in: golden))
  }

  @Test
  func `a clip's motion blur of 0 keeps it sharp under a 180° shutter`() async throws {
    let off = try await slidingSticker(shutter: 180, motionBlur: 0)
    let sharp = try await slidingSticker(shutter: 0)
    #expect(off == sharp)
  }

  @Test
  func `a sticker that stays still isn't blurred`() async throws {
    let still = try await slidingSticker(shutter: 180, travel: 0)
    let sharp = try await slidingSticker(shutter: 0, travel: 0)
    #expect(still == sharp)
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// How many pixels along the middle row are partly disc, partly background: the width of the
  /// disc's soft edges.
  private func smear(across png: Data) throws -> Int {
    try (0 ..< 160).count { step in
      let color = try PixelProbe.color(of: png, x: Double(step) / 160, y: 0.5)
      return (40 ... 200).contains(color.red)
    }
  }

  /// The orange disc sticker over blue video at 0.25 s, sliding `travel` frame widths a second
  /// (passing the centre then), under a `shutter`-degree shutter.
  private func slidingSticker(
    shutter: Double,
    motionBlur: Double = 1,
    travel: Double = 4,
  ) async throws -> Data {
    let picture = Media(
      url: try ImageFixture.makeDisc(),
      duration: Media.stillLength,
      width: 400,
      height: 300,
      hasAudio: false,
      isStill: true,
    )
    let blue = Media(
      url: try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 1),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let sticker = Clip(
      mediaID: picture.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      transform: ClipTransform(scale: 0.5),
      keyframes: [
        Keyframe(property: .x, time: .zero, value: -travel / 4),
        Keyframe(property: .x, time: MediaTime(seconds: 0.5), value: travel / 4),
      ],
      sticker: StickerLook(),
      motionBlur: motionBlur,
    )
    let tracks = [
      Track(kind: .video, clips: [Clip(
        mediaID: blue.id,
        sourceStart: .zero,
        duration: MediaTime(seconds: 1),
        timelineStart: .zero,
      )]),
      Track(kind: .video, clips: [sticker]),
    ]
    let project = Project(
      media: [blue, picture],
      timeline: Timeline(format: .half, tracks: tracks, shutterAngle: shutter),
    )
    return try await FrameRenderer.png(of: project, atSeconds: 0.25, maxSide: 320)
  }

}
