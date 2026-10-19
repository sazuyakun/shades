import Foundation
import ImageIO
import ShadesCore
import ShadesExport
import ShadesTestSupport
import Testing

@MainActor
struct StillExporterTests {

  // MARK: Internal

  @Test
  func `a frame exports as a full-size png`() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).png")
    try await StillExporter.frame(of: project(), atSeconds: 0.5, to: url)
    let png = try Data(contentsOf: url)
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 640 && image.height == 480)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).blue > 200)
  }

  @Test
  func `a gif loops a stretch at 15 frames a second, small`() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gif")
    try await StillExporter.gif(
      of: project(),
      range: TimeRange(start: .zero, end: MediaTime(seconds: 1)),
      to: url,
      maxSide: 320,
      progress: { _ in },
    )
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    #expect(CGImageSourceGetCount(source) == 15)
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 320)
  }

  @Test
  func `a gif longer than half a minute is refused`() async throws {
    await #expect(throws: ExportError.tooLong(seconds: 40, limit: 30)) {
      try await StillExporter.gif(
        of: Project(),
        range: TimeRange(start: .zero, end: MediaTime(seconds: 40)),
        to: FileManager.default.temporaryDirectory.appending(path: "long.gif"),
        progress: { _ in },
      )
    }
  }

  // MARK: Private

  /// 2 seconds of blue at 640×480.
  private func project() async throws -> Project {
    let blue = FixtureColor(red: 0, green: 0, blue: 255)
    let video = Media(
      url: try await VideoFixture.make(
        left: blue,
        right: blue,
        seconds: 2,
        width: 640,
        height: 480,
      ),
      duration: MediaTime(seconds: 2),
      width: 640,
      height: 480,
      hasAudio: false,
    )
    return Project(media: [video], timeline: Timeline(
      format: VideoFormat(width: 640, height: 480, framesPerSecond: 24),
      tracks: [Track(kind: .video, clips: [Clip(
        mediaID: video.id,
        sourceStart: .zero,
        duration: video.duration,
        timelineStart: .zero,
      )])],
    ))
  }

}
