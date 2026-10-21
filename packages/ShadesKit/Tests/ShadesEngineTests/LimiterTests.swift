import Foundation
import ShadesAudio
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// The master limiter, end to end: worked out from the mix, then heard through the mix's taps.
struct LimiterTests {

  // MARK: Internal

  @Test
  func `piled-up sound effects still reach -14 LUFS with true peaks under -1 dBTP`() async throws {
    var project = try project()
    let before = try await measure(project)
    // why: without a limiter, keeping these clicks under -1 dBTP would hold the mix far quieter.
    #expect(before.integrated - before.peak < -14 - -1)
    let reader = MixReader(project: project)
    let profile = try await LoudnessMeter
      .profile { () throws(EngineError) in try await reader.nextChunk() }
    let normalization = try #require(profile.normalized(to: -14))
    project.timeline.gain = normalization.gain
    project.timeline.limiter = normalization.limiter
    let after = try await measure(project)
    #expect(abs(after.integrated - -14) < 0.5)
    #expect(after.peak <= -1)
  }

  @Test
  func `the limiter turns the sound down at its moments of the timeline`() async throws {
    let url = try AudioFixture.makeTone(seconds: 4, amplitude: 0.5)
    var project = project(tracks: [[clip(url, seconds: 4)]])
    let open = try await measure(project)
    project.timeline.limiter = [
      GainPoint(time: MediaTime(seconds: 0), gain: 0.5),
      GainPoint(time: MediaTime(seconds: 4), gain: 0.5),
    ]
    let limited = try await measure(project)
    #expect(abs(open.integrated - limited.integrated - 6.02) < 0.3)
    #expect(abs(open.peak - limited.peak - 6.02) < 0.3)
  }

  // MARK: Private

  /// A quiet tone on A1 and loud clicks on A2, six seconds each.
  private func project() throws -> Project {
    let speech = try AudioFixture.makeTone(seconds: 6, amplitude: 0.05)
    let clicks = try AudioFixture.makeClicks(beatsPerMinute: 120, seconds: 6)
    return project(tracks: [[clip(speech, seconds: 6)], [clip(clicks, seconds: 6)]])
  }

  private func project(tracks: [[(Media, Clip)]]) -> Project {
    Project(
      media: tracks.flatMap { $0.map(\.0) },
      timeline: Timeline(tracks: [Track(kind: .video)] + tracks.map { clips in
        Track(kind: .audio, clips: clips.map(\.1))
      }),
    )
  }

  private func clip(_ url: URL, seconds: Double) -> (Media, Clip) {
    let media = Media(
      url: url,
      duration: MediaTime(seconds: seconds),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    return (
      media,
      Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero),
    )
  }

  private func measure(_ project: Project) async throws -> Loudness {
    let reader = MixReader(project: project)
    return try await LoudnessMeter
      .measure { () throws(EngineError) in try await reader.nextChunk() }
  }

}
