import AVFoundation
import MediaToolbox
import ShadesCore
import Synchronization

// MARK: - TrackTap

/// What happens to one track's sound as it exports (or plays, when panned), sample by sample:
/// its `SoundShaping`, the master limiter's gain and the track's pan. It runs inside
/// AVFoundation's mix as an audio tap, before the track's volume. Playback taps only panned
/// tracks: a tapped player can stall on a seek after a pause (see `AudioShaping`).
/// The tap's thread is AVFoundation's, so everything it reads is fixed when it's made. Reading a
/// mix back with `AVAssetReaderAudioMixOutput` skips ahead when a tap call runs long (as on a busy
/// Mac), so `MixReader` shapes its samples itself instead.
final class TrackTap: Sendable {

  // MARK: Lifecycle

  /// A tap that limits by `limiter` and pans by `pan`.
  init(limiter: [GainPoint], pan: Double) {
    shaping = SoundShaping(limiter: limiter, pan: pan)
  }

  // MARK: Internal

  /// A new tap running this, for one track's `AVAudioMixInputParameters`.
  func makeTap() -> MTAudioProcessingTap? {
    var callbacks = MTAudioProcessingTapCallbacks(
      version: kMTAudioProcessingTapCallbacksVersion_0,
      clientInfo: Unmanaged.passRetained(self).toOpaque(),
      init: { _, clientInfo, storage in
        storage.pointee = clientInfo
      },
      finalize: { tap in
        Unmanaged<TrackTap>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
      },
      prepare: { tap, _, format in
        let rate = format.pointee.mSampleRate
        TrackTap.from(tap).sampleRate.withLock { $0 = rate }
      },
      unprepare: nil,
      process: { tap, frames, _, buffers, framesOut, flagsOut in
        var range = CMTimeRange()
        let status = MTAudioProcessingTapGetSourceAudio(
          tap,
          frames,
          buffers,
          flagsOut,
          &range,
          framesOut,
        )
        guard status == noErr, range.start.isNumeric else {
          return
        }
        TrackTap.from(tap).process(
          UnsafeMutableAudioBufferListPointer(buffers),
          frames: Int(framesOut.pointee),
          from: range.start.seconds,
        )
      },
    )
    var tap: MTAudioProcessingTap?
    let status = MTAudioProcessingTapCreate(
      kCFAllocatorDefault,
      &callbacks,
      kMTAudioProcessingTapCreationFlag_PostEffects,
      &tap,
    )
    guard status == noErr else {
      Unmanaged.passUnretained(self).release()
      logger.error("tap.failed status=\(status, privacy: .public)")
      return nil
    }
    return tap
  }

  // MARK: Private

  private let shaping: SoundShaping
  private let sampleRate = Mutex(48000.0)

  private static func from(_ tap: MTAudioProcessingTap) -> TrackTap {
    Unmanaged<TrackTap>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
  }

  /// Limits and pans `frames` samples of every channel in `buffers`, which start `start`
  /// seconds into the timeline. Pan needs two channels, so mono
  /// sound pans only from its stereo copy (`Composition`'s `stereoSound`).
  private func process(
    _ buffers: UnsafeMutableAudioBufferListPointer,
    frames: Int,
    from start: Double,
  ) {
    let rate = sampleRate.withLock(\.self)
    let limiting = shaping.isLimiting
      ? (0 ..< frames).map { shaping.limiterGain(at: start + Double($0) / rate) }
      : nil
    let channelCount = buffers.reduce(0) { $0 + Int(max($1.mNumberChannels, 1)) }
    var first = 0
    for buffer in buffers {
      let channels = Int(max(buffer.mNumberChannels, 1))
      defer { first += channels }
      guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
        continue
      }
      for channel in 0 ..< channels {
        let index = first + channel
        let pan = channelCount == 2 ? (index == 0 ? shaping.left : shaping.right) : 1
        for frame in 0 ..< min(frames, Int(buffer.mDataByteSize) / 4 / channels) {
          let sample = frame * channels + channel
          data[sample] *= pan * (limiting?[frame] ?? 1)
        }
      }
    }
  }

}
