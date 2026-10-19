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
  func `a timeline without sound reads nothing`() async throws {
    let reader = MixReader(project: Project())
    #expect(try await reader.nextChunk() == nil)
  }

  // MARK: Private

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
