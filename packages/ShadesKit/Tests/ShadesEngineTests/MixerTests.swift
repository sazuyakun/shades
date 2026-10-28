import AVFoundation
import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Pan, solo and the limiter, heard through the same mix playback and export use.
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
  func `playback taps only a panned track, so its seeks don't stall`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5)
    var project = project(url, pan: 0)
    project.timeline.limiter = [GainPoint(time: .zero, gain: 0.5)]
    let plain = try await composition(of: project)
    #expect(plain.audioMix(for: project.timeline, shaping: .preview).inputParameters
      .allSatisfy { $0.audioTapProcessor == nil })
    #expect(
      plain.audioMix(for: project.timeline).inputParameters
        .contains { $0.audioTapProcessor != nil },
      "exports still limit sample by sample",
    )
    project.timeline.tracks[1].pan = -1
    let panned = try await composition(of: project)
    #expect(panned.audioMix(for: project.timeline, shaping: .preview).inputParameters
      .contains { $0.audioTapProcessor != nil })
  }

  @Test
  func `playback hears the limiter as part of each track's volume`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2, amplitude: 0.5)
    var project = project(url, pan: 0)
    project.timeline.limiter = [
      GainPoint(time: .zero, gain: 1),
      GainPoint(time: MediaTime(seconds: 1), gain: 0.5),
      GainPoint(time: MediaTime(seconds: 2), gain: 0.5),
    ]
    let mix = try await composition(of: project).audioMix(for: project.timeline, shaping: .preview)
    let parameters = try #require(mix.inputParameters.first)
    var start: Float = 0
    var end: Float = 0
    var range = CMTimeRange()
    let at = CMTime(seconds: 1.5, preferredTimescale: 600)
    #expect(parameters.getVolumeRamp(
      for: at,
      startVolume: &start,
      endVolume: &end,
      timeRange: &range,
    ))
    #expect(abs(start - 0.5) < 0.001 && abs(end - 0.5) < 0.001)
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

  /// The project's timeline laid out for playing and mixing.
  private func composition(of project: Project) async throws -> Composition {
    try await Composition.build(
      project,
      library: MediaLibrary(),
      renderState: RenderState(),
      renderContext: RenderContext(),
      frameCounter: FrameCounter(),
      quality: .full,
    )
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
