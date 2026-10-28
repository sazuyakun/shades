import Foundation
import ShadesAudio
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

struct MixReaderTests {

  // MARK: Internal

  @Test
  func `the mix reads through track levels, so half the volume measures 6 dB quieter`(
  ) async throws {
    let url = try AudioFixture.makeTone(seconds: 3, amplitude: 0.5)
    let full = try await loudness(of: url, trackVolume: 1)
    let half = try await loudness(of: url, trackVolume: 0.5)
    #expect(full.integrated.isFinite)
    #expect(abs(full.integrated - half.integrated - 6.02) < 0.3)
    #expect(abs(full.peak - half.peak - 6.02) < 0.3)
  }

  @Test
  func `clips set to clean sound play the cleaned file`() async throws {
    let original = try AudioFixture.makeTone(seconds: 3, amplitude: 0.5)
    let cleaned = try AudioFixture.makeTone(seconds: 3, amplitude: 0.25)
    let plain = try await loudness(of: original, trackVolume: 1)
    let clean = try await loudness(of: original, trackVolume: 1, cleanedTo: cleaned)
    #expect(abs(plain.integrated - clean.integrated - 6.02) < 0.3)
  }

  @Test
  func `sped-up sound plays in less time at the same level, and a freeze is silent`(
  ) async throws {
    let url = try AudioFixture.makeTone(seconds: 3, amplitude: 0.5)
    let normal = try await samples(of: url, speed: 1)
    let fast = try await samples(of: url, speed: 2)
    let audible = { (samples: [Float]) in Double(samples.count { abs($0) > 0.05 }) }
    let start = { (samples: [Float]) in samples.firstIndex { abs($0) > 0.05 } }
    #expect(start(fast) == start(normal))
    #expect(abs(audible(fast) / audible(normal) - 0.5) < 0.01)
    // why: the mix is exactly the timeline, with the sped-up sound playing to its very end.
    #expect(fast.count == 2 * 48000)
    #expect(fast.suffix(2 * 480).contains { abs($0) > 0.05 })
    #expect(abs(peak(fast) - peak(normal)) < 0.05, "the pitch-kept stretch keeps the level")
    #expect(peak(try await samples(of: url, speed: 0)) < 0.001)
  }

  @Test
  @MainActor
  func `a clip running a little past its sound's end plays and measures`() async throws {
    let url = try AudioFixture.makeTone(seconds: 1.99, amplitude: 0.5)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1.99),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    // why: lengths round to the nearest frame, so the 1.99 s file makes a 2 s clip at 24 fps.
    let project = Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.length(at: 24),
        timelineStart: .zero,
      )]),
    ]))
    try await Player().load(project)
    let reader = MixReader(project: project)
    var count = 0
    while let chunk = try await reader.nextChunk() {
      count += chunk.count
    }
    // why: the sound plays to its file's end; the last few milliseconds of the clip are silent.
    #expect(abs(count - 2 * 2 * 48000) <= 2 * 48000 / 24)
  }

  @Test
  func `a range reads just that stretch of the mix`() async throws {
    let url = try AudioFixture.makeTone(seconds: 3, amplitude: 0.5)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 3),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    var project = Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.duration,
        timelineStart: .zero,
      )]),
    ]))
    // why: the limiter is read at timeline times, so the range's sound must line up with it.
    project.timeline.limiter = [
      GainPoint(time: MediaTime(seconds: 1), gain: 0.5),
      GainPoint(time: MediaTime(seconds: 3), gain: 0.5),
    ]
    let reader = MixReader(
      project: project,
      range: TimeRange(start: MediaTime(seconds: 1.5), end: MediaTime(seconds: 2)),
    )
    var samples = [Float]()
    while let chunk = try await reader.nextChunk() {
      samples += chunk
    }
    #expect(samples.count == 2 * 24000)
    #expect(abs((samples.map(abs).max() ?? 0) - 0.25) < 0.02)
  }

  @Test
  func `a timeline without sound reads nothing`() async throws {
    let reader = MixReader(project: Project())
    #expect(try await reader.nextChunk() == nil)
  }

  // MARK: Private

  /// Every sample of a mix holding 2 seconds of `url` at `speed` (a frozen clip lasts 2 s too).
  private func samples(of url: URL, speed: Double) async throws -> [Float] {
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 3),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: MediaTime(seconds: speed == 0 ? 2 : 2 / speed),
      timelineStart: .zero,
      speed: speed,
    )
    let project = Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio, clips: [clip]),
    ]))
    let reader = MixReader(project: project)
    var samples = [Float]()
    while let chunk = try await reader.nextChunk() {
      samples += chunk
    }
    return samples
  }

  private func peak(_ samples: [Float]) -> Double {
    Double(samples.map(abs).max() ?? 0)
  }

  private func loudness(
    of url: URL,
    trackVolume: Double,
    cleanedTo cleaned: URL? = nil,
  ) async throws -> Loudness {
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 3),
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
      cleanSound: cleaned != nil,
    )
    let project = Project(media: [media], timeline: Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .audio, clips: [clip], volume: trackVolume),
    ]))
    let reader = MixReader(project: project, cleanSound: cleaned.map { [media.id: $0] } ?? [:])
    return try await LoudnessMeter
      .measure { () throws(EngineError) in try await reader.nextChunk() }
  }

}
