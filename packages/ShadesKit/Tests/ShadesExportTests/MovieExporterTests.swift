import AVFoundation
import ShadesAudio
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
    var checked = 0
    for index in stride(from: 1, to: 39, by: 3) {
      let time = Double(index) / 30
      let source = clip.sourceTime(at: MediaTime(seconds: time)).seconds
      // why: a moment on a source frame's edge may land on either side; those aren't compared.
      if let frame = VideoFixture.countedFrame(atSource: source) {
        // why: the file's frame times can land a hair after the exact moment, so it's read half
        // a frame later, still inside the same frame.
        let file = try await self.frame(of: asset, at: time + 1.0 / 60)
        let exported = try VideoFixture.countedFrame(in: file)
        let preview = try await FrameRenderer.png(of: project, atSeconds: time, maxSide: 320)
        #expect(exported == frame, "at \(time) s")
        #expect(try exported == VideoFixture.countedFrame(in: preview), "at \(time) s")
        checked += 1
      }
    }
    #expect(checked >= 6)
  }

  @Test
  func `an HLG clip exports tone-mapped and tagged as Rec.709`() async throws {
    let white = FixtureColor(red: 191, green: 191, blue: 191)
    let video = Media(
      url: try await VideoFixture.make(left: white, right: white, colorSpace: .hlg),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let project = Project(media: [video], timeline: Timeline(
      format: VideoFormat(width: 320, height: 180, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [Clip(
        mediaID: video.id,
        sourceStart: .zero,
        duration: video.duration,
        timelineStart: .zero,
      )])],
    ))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
    try await MovieExporter.export(project, to: url, canvas: .picture, progress: { _ in })
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let format = try #require(try await track.load(.formatDescriptions).first)
    let tag = { (key: CFString) in
      CMFormatDescriptionGetExtension(format, extensionKey: key) as? String
    }
    #expect(tag(kCMFormatDescriptionExtension_ColorPrimaries) == "ITU_R_709_2")
    #expect(tag(kCMFormatDescriptionExtension_TransferFunction) == "ITU_R_709_2")
    #expect(tag(kCMFormatDescriptionExtension_YCbCrMatrix) == "ITU_R_709_2")
    let frame = try await frame(of: asset, at: 0.5)
    let center = try PixelProbe.color(of: frame, x: 0.5, y: 0.5)
    #expect(center.red > 225, "got \(center)")
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

  @Test
  func `the export plays the mix as playback does, through the master limiter`() async throws {
    let open = try await loudness(of: export(canvas: .picture))
    let limited = try await loudness(of: export(canvas: .picture) { timeline in
      timeline.limiter = [
        GainPoint(time: .zero, gain: 0.25),
        GainPoint(time: MediaTime(seconds: 2), gain: 0.25),
      ]
    })
    #expect(abs(open.peak - limited.peak - 12.04) < 0.5)
  }

  // MARK: Private

  /// Exports 2 seconds of red with a tone, at 640×480, with `mix` changing the timeline.
  private func export(
    canvas: Canvas,
    range: TimeRange? = nil,
    mix: (inout Timeline) -> Void = { _ in },
  ) async throws -> URL {
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
    var project = Project(media: [video, tone], timeline: Timeline(
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
    mix(&project.timeline)
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

  /// The loudness of the sound in the exported file at `url`.
  private func loudness(of url: URL) async throws -> Loudness {
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 2),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let reader = MixReader(project: Project(
      media: [media],
      timeline: Timeline(tracks: [Track(kind: .video), Track(kind: .audio, clips: [clip])]),
    ))
    return try await LoudnessMeter
      .measure { () throws(EngineError) in try await reader.nextChunk() }
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
