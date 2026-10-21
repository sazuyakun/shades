import AVFoundation
import MediaToolbox
import ShadesCore
import Synchronization

// MARK: - TrackTap

/// What happens to one track's sound as it plays or exports, sample by sample: the master
/// limiter's gain. It runs inside AVFoundation's mix as an audio tap, before the track's volume.
/// The tap's thread is AVFoundation's, so everything it reads is fixed when it's made.
final class TrackTap: Sendable {

  // MARK: Lifecycle

  init(limiter: [GainPoint]) {
    times = limiter.map(\.time.seconds)
    gains = limiter.map(\.gain)
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

  /// The limiter's points, in seconds and linear gain.
  private let times: [Double]
  private let gains: [Double]
  private let sampleRate = Mutex(48000.0)

  private static func from(_ tap: MTAudioProcessingTap) -> TrackTap {
    Unmanaged<TrackTap>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
  }

  /// Scales `frames` samples of every channel in `buffers`, which start `start` seconds into the
  /// timeline, by the limiter's gain.
  private func process(
    _ buffers: UnsafeMutableAudioBufferListPointer,
    frames: Int,
    from start: Double,
  ) {
    guard !times.isEmpty else {
      return
    }
    let rate = sampleRate.withLock(\.self)
    let level = (0 ..< frames).map { limiterGain(at: start + Double($0) / rate) }
    for buffer in buffers {
      guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
        continue
      }
      let channels = Int(max(buffer.mNumberChannels, 1))
      for frame in 0 ..< min(frames, Int(buffer.mDataByteSize) / 4 / channels) {
        for channel in 0 ..< channels {
          data[frame * channels + channel] *= Float(level[frame])
        }
      }
    }
  }

  /// The limiter's gain at `time`: straight lines between its points, holding the end ones.
  private func limiterGain(at time: Double) -> Double {
    guard let first = times.first, let last = times.last, time > first else {
      return gains.first ?? 1
    }
    guard time < last else {
      return gains[gains.count - 1]
    }
    var low = 0
    var high = times.count - 1
    while high - low > 1 {
      let middle = (low + high) / 2
      if times[middle] <= time {
        low = middle
      } else {
        high = middle
      }
    }
    let share = (time - times[low]) / (times[high] - times[low])
    return gains[low] + (gains[high] - gains[low]) * share
  }

}
