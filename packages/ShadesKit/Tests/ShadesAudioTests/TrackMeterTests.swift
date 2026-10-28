import Foundation
import ShadesAudio
import ShadesCore
import Testing

struct TrackMeterTests {

  // MARK: Internal

  @Test
  func `a meter reads the clip's waveform at the moment, as a level`() throws {
    let (timeline, track) = timeline(pan: 0)
    let loud = try #require(TrackMeter.level(
      of: track,
      in: timeline,
      at: MediaTime(seconds: 0.01),
      waveforms: [media.id: [1, 0.5]],
    ))
    #expect(abs(loud.left - 1) < 0.001 && abs(loud.right - 1) < 0.001)
    let quieter = try #require(TrackMeter.level(
      of: track,
      in: timeline,
      at: MediaTime(seconds: 0.05),
      waveforms: [media.id: [1, 0.5]],
    ))
    // why: 0.5 on the waveform's 40 dB scale is −20 dB, a tenth of full scale.
    #expect(abs(quieter.left - 0.1) < 0.001)
  }

  @Test
  func `the pan leans the reading, and silence or no waveform reads as nothing`() {
    let (timeline, track) = timeline(pan: -1)
    let left = TrackMeter.level(
      of: track,
      in: timeline,
      at: MediaTime(seconds: 0.01),
      waveforms: [media.id: [1]],
    )
    #expect(left?.right == 0 && left?.left == 1)
    #expect(TrackMeter.level(
      of: track,
      in: timeline,
      at: MediaTime(seconds: 0.01),
      waveforms: [:],
    ) == nil)
    #expect(TrackMeter.level(
      of: track,
      in: timeline,
      at: MediaTime(seconds: 0.01),
      waveforms: [media.id: [0]],
    ) == MeterLevel(left: 0, right: 0))
  }

  // MARK: Private

  private let media = Media(
    url: URL(filePath: "/tmp/sound.wav"),
    duration: MediaTime(seconds: 2),
    width: 0,
    height: 0,
    hasVideo: false,
    hasAudio: true,
  )

  /// A timeline with the sound on A1, panned by `pan`.
  private func timeline(pan: Double) -> (Timeline, Track) {
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let track = Track(kind: .audio, clips: [clip], pan: pan)
    return (Timeline(tracks: [Track(kind: .video), track]), track)
  }

}
