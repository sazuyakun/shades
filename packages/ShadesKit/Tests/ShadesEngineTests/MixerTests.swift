import AVFoundation
import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Pan, solo and meters, heard through the same mix playback and export use.
@MainActor
struct MixerTests {

  // MARK: Internal

  @Test
  func `panning a stereo track moves its sound between the channels`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5, channels: 2)
    let hardLeft = try await peaks(of: project(url, pan: -1))
    #expect(abs(hardLeft.left - 0.5) < 0.02)
    #expect(hardLeft.right < 0.01)
    let halfRight = try await peaks(of: project(url, pan: 0.5))
    #expect(abs(halfRight.left - 0.25) < 0.02)
    #expect(abs(halfRight.right - 0.5) < 0.02)
  }

  @Test
  func `a mono track pans through its stereo copy, and stays centred without one`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5)
    let project = project(url, pan: -1)
    let centred = try await peaks(of: project)
    #expect(abs(centred.left - centred.right) < 0.01)
    let mediaID = try #require(project.media.first?.id)
    let copy = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5, channels: 2)
    let panned = try await peaks(of: project, stereoSound: [mediaID: copy])
    #expect(abs(panned.left - 0.5) < 0.02)
    #expect(panned.right < 0.01)
  }

  @Test
  func `soloing a track leaves only it in the mix`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.25)
    var both = project(url, pan: 0)
    both.timeline.tracks.append(Track(kind: .audio, clips: both.timeline.tracks[1].clips))
    let together = try await peaks(of: both)
    both.timeline.tracks[2].isSoloed = true
    let alone = try await peaks(of: both)
    #expect(abs(together.left - 0.5) < 0.02)
    #expect(abs(alone.left - 0.25) < 0.02)
  }

  @Test
  func `meters read each track's level at a moment, before its volume`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5, channels: 2)
    var project = project(url, pan: -1)
    project.timeline.tracks[1].volume = 0.5
    let composition = try await Composition.build(
      project,
      library: MediaLibrary(),
      renderState: RenderState(),
      renderContext: RenderContext(),
      frameCounter: FrameCounter(),
      quality: .full,
    )
    let meters = MixMeters()
    let reader = try AVAssetReader(asset: composition.asset)
    let output = AVAssetReaderAudioMixOutput(
      audioTracks: composition.asset.tracks(withMediaType: .audio),
      audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
        AVLinearPCMIsBigEndianKey: false,
      ],
    )
    output.audioMix = composition.audioMix(for: project.timeline, meters: meters)
    reader.add(output)
    #expect(reader.startReading())
    while output.copyNextSampleBuffer() != nil { }
    let level = try #require(meters.level(of: project.timeline.tracks[1].id, at: 1))
    #expect(abs(level.left - 0.5) < 0.02)
    #expect(level.right < 0.01)
    #expect(meters.level(of: project.timeline.tracks[0].id, at: 1) == nil)
  }

  // MARK: Private

  /// `url`'s two seconds on A1, panned by `pan`.
  private func project(_ url: URL, pan: Double) -> Project {
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
    return Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio, clips: [clip], pan: pan),
    ]))
  }

  /// The loudest sample of each channel of the project's mix.
  private func peaks(
    of project: Project,
    stereoSound: [Media.ID: URL] = [:],
  ) async throws -> (left: Float, right: Float) {
    let reader = MixReader(project: project, stereoSound: stereoSound)
    var left: Float = 0
    var right: Float = 0
    while let chunk = try await reader.nextChunk() {
      for index in stride(from: 0, to: chunk.count - 1, by: 2) {
        left = max(left, abs(chunk[index]))
        right = max(right, abs(chunk[index + 1]))
      }
    }
    return (left, right)
  }

}
