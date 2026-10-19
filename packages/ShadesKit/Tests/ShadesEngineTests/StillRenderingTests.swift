import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Still pictures and stickers drawn as layers.
struct StillRenderingTests {

  // MARK: Internal

  @Test
  func `a still picture plays on its own for as long as it's placed`() async throws {
    let png = try await frame(over: false, sticker: nil)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: png, x: 0.05, y: 0.5).red < 30)
  }

  @Test
  func `a see-through still shows the video around it`() async throws {
    let png = try await frame(over: true, sticker: nil)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: png, x: 0.1, y: 0.5).blue > 200)
  }

  @Test
  func `a sticker gets a white die-cut border`() async throws {
    let png = try await frame(over: true, sticker: StickerLook(border: 0.06, shadow: true))
    let rim = try (30 ..< 50).map { row in
      try PixelProbe.color(of: png, x: 0.5, y: Double(row) / 100 - 0.25)
    }
    #expect(rim.contains { $0.red > 220 && $0.green > 220 && $0.blue > 220 })
    #expect(try GoldenFrame.matches(png, named: "sticker-die-cut", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// The orange disc picture as a 10-second clip, over blue video or on its own.
  private func frame(over video: Bool, sticker: StickerLook?) async throws -> Data {
    let pictureURL = try ImageFixture.makeDisc()
    let picture = Media(
      url: pictureURL,
      duration: Media.stillLength,
      width: 400,
      height: 300,
      hasAudio: false,
      isStill: true,
    )
    var media = [picture]
    var tracks = [Track(kind: .video, clips: [Clip(
      mediaID: picture.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 10),
      timelineStart: .zero,
      sticker: sticker,
    )])]
    if video {
      let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 1)
      let blue = Media(
        url: url,
        duration: MediaTime(seconds: 1),
        width: 320,
        height: 180,
        hasAudio: false,
      )
      media.append(blue)
      tracks.insert(Track(kind: .video, clips: [Clip(
        mediaID: blue.id,
        sourceStart: .zero,
        duration: MediaTime(seconds: 1),
        timelineStart: .zero,
      )]), at: 0)
    }
    let project = Project(media: media, timeline: Timeline(format: .half, tracks: tracks))
    return try await FrameRenderer.png(of: project, atSeconds: video ? 0.5 : 8, maxSide: 320)
  }

}
