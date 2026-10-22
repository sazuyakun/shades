import AVFoundation
import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// HDR and wide-colour footage brought into the Rec.709 working space.
@MainActor
struct ColorRenderingTests {

  // MARK: Internal

  @Test
  func `HLG reference white comes out just under SDR white`() async throws {
    let white = try await center(of: FixtureColor(red: 191, green: 191, blue: 191), in: .hlg)
    #expect((235 ... 250).contains(white.red), "got \(white.red)")
    #expect(abs(Int(white.red) - Int(white.blue)) < 4, "stays neutral")
  }

  @Test
  func `HLG mid grey stays near SDR mid grey and black stays black`() async throws {
    let grey = try await center(of: FixtureColor(red: 128, green: 128, blue: 128), in: .hlg)
    #expect((132 ... 155).contains(grey.red), "got \(grey.red)")
    let black = try await center(of: FixtureColor(red: 0, green: 0, blue: 0), in: .hlg)
    #expect(black.red < 8)
  }

  @Test
  func `PQ at reference white matches HLG at reference white`() async throws {
    // why: 148 is PQ's code for about 203 nits, BT.2408's reference white.
    let white = try await center(of: FixtureColor(red: 148, green: 148, blue: 148), in: .pq)
    #expect((233 ... 250).contains(white.red), "got \(white.red)")
  }

  @Test
  func `Rec.709 footage is drawn exactly as it is`() async throws {
    let grey = try await center(of: FixtureColor(red: 191, green: 191, blue: 191), in: .rec709)
    #expect(abs(Int(grey.red) - 191) < 4, "got \(grey.red)")
  }

  @Test
  func `wide-gamut colours are brought into Rec.709, more saturated`() async throws {
    let orange = FixtureColor(red: 200, green: 100, blue: 50)
    let p3 = try await center(of: orange, in: .displayP3)
    #expect(p3.red > 208 && p3.blue < 44, "got \(p3), tags \(try await frameTags(of: orange))")
    let hlg = try await center(of: orange, in: .hlg)
    #expect(hlg.red > hlg.green + 120, "Rec.2020 orange is redder in Rec.709: got \(hlg)")
  }

  // MARK: Private

  /// The colour tags on a composed frame of a P3 clip, which AVFoundation copies from its source.
  private func frameTags(of color: FixtureColor) async throws -> String {
    let url = try await VideoFixture.make(left: color, right: color, colorSpace: .displayP3)
    let media = Media(url: url, duration: MediaTime(seconds: 1), width: 320, height: 180, hasAudio: false)
    let project = Project(media: [media], timeline: Timeline(
      format: VideoFormat(width: 320, height: 180, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero)])],
    ))
    let composition = try await Composition.forRendering(project)
    let reader = try AVAssetReader(asset: composition.asset)
    let output = AVAssetReaderVideoCompositionOutput(
      videoTracks: composition.asset.tracks(withMediaType: .video),
      videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA],
    )
    output.videoComposition = composition.videoComposition
    reader.add(output)
    reader.startReading()
    let frame = try #require(output.copyNextSampleBuffer().flatMap(CMSampleBufferGetImageBuffer))
    let tags = CVBufferCopyAttachments(frame, .shouldPropagate) as NSDictionary?
    return "\(String(describing: tags))"
  }

  /// The middle of a frame of a clip of `color`, stored with `colorSpace`'s tags.
  private func center(
    of color: FixtureColor,
    in colorSpace: FixtureColorSpace,
  ) async throws -> (red: UInt8, green: UInt8, blue: UInt8) {
    let url = try await VideoFixture.make(left: color, right: color, colorSpace: colorSpace)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let project = Project(media: [media], timeline: Timeline(
      format: VideoFormat(width: 320, height: 180, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.duration,
        timelineStart: .zero,
      )])],
    ))
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    return try PixelProbe.color(of: png, x: 0.5, y: 0.5)
  }

}
