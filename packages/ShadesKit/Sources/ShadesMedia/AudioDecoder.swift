import AudioToolbox
import AVFoundation
import Synchronization

/// Decodes the sound of any audio or video file into mono or stereo samples at a chosen rate, for
/// speech recognition, audio analysis and stem separation.
public enum AudioDecoder {

  // MARK: Public

  /// How many channels the file's sound has (1 mono, 2 stereo), or 0 when it has none.
  public static func channelCount(of url: URL) async throws(MediaError) -> Int {
    do {
      guard let track = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio).first
      else {
        return 0
      }
      let formats = try await track.load(.formatDescriptions)
      return formats.compactMap { format in
        CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee.mChannelsPerFrame
      }.map(Int.init).max() ?? 0
    } catch {
      logger.error("samples.failed reason=channels path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
  }

  /// The file's sound as mono samples from -1 to 1, `sampleRate` per second.
  @concurrent
  public static func mono(from url: URL, sampleRate: Double) async throws(MediaError) -> [Float] {
    try await samples(from: url, sampleRate: sampleRate, channels: 1).samples
  }

  /// The file's sound as left and right samples from -1 to 1, `sampleRate` per second. A mono
  /// file plays the same in both.
  @concurrent
  public static func stereo(
    from url: URL,
    sampleRate: Double,
  ) async throws(MediaError) -> (left: [Float], right: [Float]) {
    let (samples, channels) = try await samples(from: url, sampleRate: sampleRate, channels: 2)
    guard channels == 2 else {
      return (samples, samples)
    }
    let frames = samples.count / 2
    return (
      (0 ..< frames).map { samples[$0 * 2] },
      (0 ..< frames).map { samples[$0 * 2 + 1] },
    )
  }

  // MARK: Private

  private static let queue = DispatchQueue(
    label: "com.sazuyakun.shades.audio-decode",
    qos: .utility,
    attributes: .concurrent,
  )
  /// Frames read per chunk.
  private static let chunk = 32768

  /// Interleaved samples with up to `channels` channels (fewer when the file has fewer), and
  /// how many there are.
  private static func samples(
    from url: URL,
    sampleRate: Double,
    channels: Int,
  ) async throws(MediaError) -> (samples: [Float], channels: Int) {
    let hasSound: Bool
    do {
      hasSound = try await !AVURLAsset(url: url).loadTracks(withMediaType: .audio).isEmpty
    } catch {
      logger.error("samples.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    guard hasSound else {
      logger.error("samples.failed reason=noAudio path=\(url.path, privacy: .private)")
      throw .noAudio(url)
    }
    let cancelled = Atomic(false)
    // why: decoding blocks its thread; on Swift's small cooperative pool, several decodes at once
    // can take every thread and deadlock, so the blocking loop runs on a dispatch queue.
    let result = await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        queue.async {
          continuation.resume(returning: decode(
            url,
            sampleRate: sampleRate,
            channels: channels,
            cancelled: cancelled,
          ))
        }
      }
    } onCancel: {
      cancelled.store(true, ordering: .relaxed)
    }
    return try result.get()
  }

  /// The blocking part: reads the file through ExtAudioFile, which converts it to interleaved
  /// `Float`s at `sampleRate` as it reads.
  private static func decode(
    _ url: URL,
    sampleRate: Double,
    channels wanted: Int,
    cancelled: borrowing Atomic<Bool>,
  ) -> Result<(samples: [Float], channels: Int), MediaError> {
    var opened: ExtAudioFileRef?
    guard ExtAudioFileOpenURL(url as CFURL, &opened) == noErr, let file = opened else {
      logger.error("samples.failed reason=open path=\(url.path, privacy: .private)")
      return .failure(.unreadable(url))
    }
    defer { ExtAudioFileDispose(file) }
    var fileFormat = AudioStreamBasicDescription()
    var fileFormatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard
      ExtAudioFileGetProperty(
        file,
        kExtAudioFileProperty_FileDataFormat,
        &fileFormatSize,
        &fileFormat,
      )
      == noErr
    else {
      logger.error("samples.failed reason=format path=\(url.path, privacy: .private)")
      return .failure(.unreadable(url))
    }
    let channels = max(min(wanted, Int(fileFormat.mChannelsPerFrame)), 1)
    var format = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: UInt32(4 * channels),
      mFramesPerPacket: 1,
      mBytesPerFrame: UInt32(4 * channels),
      mChannelsPerFrame: UInt32(channels),
      mBitsPerChannel: 32,
      mReserved: 0,
    )
    let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    guard
      ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, size, &format) ==
      noErr
    else {
      logger.error("samples.failed reason=format path=\(url.path, privacy: .private)")
      return .failure(.unreadable(url))
    }
    var samples = [Float]()
    var buffer = [Float](repeating: 0, count: chunk * channels)
    while true {
      guard !cancelled.load(ordering: .relaxed) else {
        return .failure(.cancelled(url))
      }
      var frames = UInt32(chunk)
      let status = buffer.withUnsafeMutableBytes { bytes -> OSStatus in
        var list = AudioBufferList(
          mNumberBuffers: 1,
          mBuffers: AudioBuffer(
            mNumberChannels: UInt32(channels),
            mDataByteSize: UInt32(bytes.count),
            mData: bytes.baseAddress,
          ),
        )
        return ExtAudioFileRead(file, &frames, &list)
      }
      guard status == noErr else {
        logger.error("samples.failed reason=read status=\(status, privacy: .public)")
        return .failure(.unreadable(url))
      }
      guard frames > 0 else {
        return .success((samples, channels))
      }
      samples.append(contentsOf: buffer.prefix(Int(frames) * channels))
    }
  }

}
