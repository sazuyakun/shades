import AVFoundation
import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

@MainActor
struct AudioMixTests {
  @Test
  func `the mix fades clips in and scales them by track and master level`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2)
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
      fadeIn: MediaTime(seconds: 1),
    )
    let timeline = Timeline(
      format: .half,
      tracks: [Track(kind: .video), Track(kind: .audio, clips: [clip], volume: 0.5)],
      gain: 2,
    )
    let project = Project(media: [media], timeline: timeline)
    let composition = try await Composition.build(
      project,
      library: MediaLibrary(),
      renderState: RenderState(),
      renderContext: RenderContext(),
      frameCounter: FrameCounter(),
    )
    let parameters = try #require(composition.audioMix(for: timeline).inputParameters.first)
    var start: Float = 0
    var end: Float = 0
    var range = CMTimeRange()
    #expect(parameters.getVolumeRamp(
      for: CMTime(value: 1, timescale: 2),
      startVolume: &start,
      endVolume: &end,
      timeRange: &range,
    ))
    #expect(start == 0 && end == 1)
    #expect(range.duration.seconds == 1)
  }
}
