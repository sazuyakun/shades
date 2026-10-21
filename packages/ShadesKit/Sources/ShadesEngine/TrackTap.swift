import AVFoundation
import MediaToolbox
import ShadesCore
import Synchronization

// MARK: - TrackTap

/// What happens to one track's sound as it plays or exports, sample by sample: the master
/// limiter's gain and the track's pan, then a reading for the mixer's meters. It runs inside
/// AVFoundation's mix as an audio tap, before the track's volume. The tap's thread is
/// AVFoundation's, so everything it reads is fixed when it's made.
final class TrackTap: Sendable {

  // MARK: Lifecycle

  /// A tap for `track` that limits by `limiter`, pans by `pan` and reports to `meters`.
  init(track: Track.ID, limiter: [GainPoint], pan: Double, meters: MixMeters?) {
    self.track = track
    times = limiter.map(\.time.seconds)
    gains = limiter.map(\.gain)
    // why: a balance control: the far side fades out and the near side stays as recorded.
    channelGains = [min(1, 1 - pan), min(1, 1 + pan)]
    self.meters = meters
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

  private let track: Track.ID
  /// The limiter's points, in seconds and linear gain.
  private let times: [Double]
  private let gains: [Double]
  /// The left and right channels' gains from the pan.
  private let channelGains: [Double]
  private let meters: MixMeters?
  private let sampleRate = Mutex(48000.0)

  private static func from(_ tap: MTAudioProcessingTap) -> TrackTap {
    Unmanaged<TrackTap>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
  }

  /// Limits and pans `frames` samples of every channel in `buffers`, which start `start`
  /// seconds into the timeline, and reports their loudest points. Pan needs two channels; mono
  /// stays centred.
  private func process(
    _ buffers: UnsafeMutableAudioBufferListPointer,
    frames: Int,
    from start: Double,
  ) {
    let rate = sampleRate.withLock(\.self)
    let limiting = times.isEmpty
      ? nil
      : (0 ..< frames).map { limiterGain(at: start + Double($0) / rate) }
    let channelCount = buffers.reduce(0) { $0 + Int(max($1.mNumberChannels, 1)) }
    var loudest = [Float](repeating: 0, count: channelCount)
    var first = 0
    for buffer in buffers {
      let channels = Int(max(buffer.mNumberChannels, 1))
      defer { first += channels }
      guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
        continue
      }
      for channel in 0 ..< channels {
        let index = first + channel
        let pan = channelCount == 2 ? Float(channelGains[index]) : 1
        for frame in 0 ..< min(frames, Int(buffer.mDataByteSize) / 4 / channels) {
          let sample = frame * channels + channel
          data[sample] *= pan * Float(limiting?[frame] ?? 1)
          loudest[index] = max(loudest[index], abs(data[sample]))
        }
      }
    }
    meters?.record(
      MeterLevel(left: Double(loudest.first ?? 0), right: Double(loudest.last ?? 0)),
      for: track,
      from: start,
      to: start + Double(frames) / rate,
    )
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
