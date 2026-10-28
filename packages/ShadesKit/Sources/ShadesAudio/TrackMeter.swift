import Foundation
import ShadesCore

/// What the mixer's meters show: how loud a track's sound is at a moment, read from its clips'
/// waveforms, so nothing has to listen to the sound as it plays.
public enum TrackMeter {

  /// The loudest point of `track`'s sound around `time`, before its clip's and its own volume,
  /// leaned by its pan, from `waveforms` (each media file's `Waveform` peaks); `nil` when no
  /// clip plays there or its waveform isn't drawn yet.
  public static func level(
    of track: Track,
    in timeline: Timeline,
    at time: MediaTime,
    waveforms: [Media.ID: [Float]],
  ) -> MeterLevel? {
    guard
      let clip = track.clip(at: time), timeline.plays(clip, on: track), !clip.isFrozen,
      let peaks = clip.mediaID.flatMap({ waveforms[$0] })
    else {
      return nil
    }
    let index = Int(clip.sourceTime(at: time).seconds * Waveform.peaksPerSecond)
    guard peaks.indices.contains(index) else {
      return nil
    }
    // why: peaks are on a decibel scale from 0 (−40 dB or quieter, read as silence) to 1.
    let peak = Double(peaks[index])
    let level = peak > 0 ? pow(10, (peak - 1) * Waveform.decibelRange / 20) : 0
    // why: a waveform is mono; the pan leans it like a balance control, as the mix does.
    return MeterLevel(left: level * min(1, 1 - track.pan), right: level * min(1, 1 + track.pan))
  }

}
