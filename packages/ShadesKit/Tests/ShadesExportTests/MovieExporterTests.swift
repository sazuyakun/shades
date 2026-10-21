import AVFoundation
import ShadesCore
import ShadesEngine
import ShadesExport
import ShadesTestSupport
import Testing

@MainActor
struct MovieExporterTests {

  // MARK: Internal

  @Test
  func `a youtube export is the picture centred on 16:9 black, with its sound`() async throws {
    let url = try await export(canvas: .youtube)
    let asset = AVURLAsset(url: url)
    let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
    #expect(try await video.load(.naturalSize) == CGSize(width: 854, height: 480))
    #expect(try await !asset.loadTracks(withMediaType: .audio).isEmpty)
    #expect(try abs(await asset.load(.duration).seconds - 2) < 0.1)
    let frame = try await frame(of: asset, at: 1)
    #expect(try PixelProbe.color(of: frame, x: 0.5, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: frame, x: 0.03, y: 0.5).red < 20)
  }

  @Test
  func `a short exports only its range, on the vertical canvas`() async throws {
    let url = try await export(
      canvas: .vertical,
      range: TimeRange(start: MediaTime(seconds: 0.5), end: MediaTime(seconds: 1.5)),
    )
    let asset = AVURLAsset(url: url)
    let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
    #expect(try await video.load(.naturalSize) == CGSize(width: 1080, height: 1920))
    #expect(try abs(await asset.load(.duration).seconds - 1) < 0.1)
    let frame = try await frame(of: asset, at: 0.5)
    #expect(try PixelProbe.color(of: frame, x: 0.5, y: 0.5).red > 200)
    #expect(try PixelProbe.color(of: frame, x: 0.5, y: 0.05).red < 20)
  }

  @Test
  func `an exported speed ramp lands on the same source frames as playback`() async throws {
    let media = Media(
      url: try await VideoFixture.makeCounting(),
      duration: MediaTime(seconds: 2),
      width: 320,
      height: 240,
      hasAudio: false,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1.3),
      timelineStart: .zero,
      keyframes: [
        Keyframe(property: .speed, time: .zero, value: 0.5, easing: .easeInOut),
        Keyframe(property: .speed, time: MediaTime(seconds: 1), value: 2),
      ],
    )
    let project = Project(media: [media], timeline: Timeline(
      format: VideoFormat(width: 320, height: 240, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [clip])],
    ))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
    try await MovieExporter.export(project, to: url, canvas: .picture, progress: { _ in })
    let asset = AVURLAsset(url: url)
    for frame in [3, 12, 21, 30, 38] {
      let time = Double(frame) / 30
      let source = clip.sourceTime(at: MediaTime(seconds: time)).seconds
      let preview = try await FrameRenderer.png(of: project, atSeconds: time, maxSide: 320)
      let exported = try await self.frame(of: asset, at: time)
      #expect(try VideoFixture
        .countedFrame(in: exported) == Int((source * 30 + 0.001).rounded(.down)))
      #expect(try VideoFixture.countedFrame(in: exported) == VideoFixture.countedFrame(in: preview))
    }
  }

  @Test
  func `an empty timeline has nothing to export`() async {
    await #expect(throws: ExportError.nothingToExport("the timeline is empty")) {
      try await MovieExporter.export(
        Project(),
        to: FileManager.default.temporaryDirectory.appending(path: "empty.mp4"),
        canvas: .youtube,
        progress: { _ in },
      )
    }
  }

  // MARK: Private

  /// Exports 2 seconds of red with a tone, at 640×480.
  private func export(canvas: Canvas, range: TimeRange? = nil) async throws -> URL {
    let red = FixtureColor(red: 255, green: 0, blue: 0)
    let video = Media(
      url: try await VideoFixture.make(left: red, right: red, seconds: 2, width: 640, height: 480),
      duration: MediaTime(seconds: 2),
      width: 640,
      height: 480,
      hasAudio: false,
    )
    let tone = Media(
      url: try AudioFixture.makeTone(seconds: 2),
      duration: MediaTime(seconds: 2),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    let project = Project(media: [video, tone], timeline: Timeline(
      format: VideoFormat(width: 640, height: 480, framesPerSecond: 24),
      tracks: [
        Track(kind: .video, clips: [Clip(
          mediaID: video.id,
          sourceStart: .zero,
          duration: video.duration,
          timelineStart: .zero,
        )]),
        Track(kind: .audio, clips: [Clip(
          mediaID: tone.id,
          sourceStart: .zero,
          duration: tone.duration,
          timelineStart: .zero,
        )]),
      ],
    ))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
    try await MovieExporter.export(
      project,
      to: url,
      canvas: canvas,
      range: range,
      progress: { _ in },
    )
    return url
  }

  private func frame(of asset: AVURLAsset, at seconds: Double) async throws -> Data {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let (image, _) = try await generator.image(at: CMTime(
      seconds: seconds,
      preferredTimescale: 600,
    ))
    return try FrameRenderer.pngData(from: image)
  }

}
