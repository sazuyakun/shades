import AudioToolbox
import AVFoundation
import Synchronization

/// Decodes the sound of any audio or video file into mono samples at a chosen rate, for speech
/// recognition and audio analysis.
public enum AudioDecoder {

  // MARK: Public

  /// The file's sound as mono samples from -1 to 1, `sampleRate` per second.
  @concurrent
  public static func mono(from url: URL, sampleRate: Double) async throws(MediaError) -> [Float] {
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
          continuation.resume(returning: decode(url, sampleRate: sampleRate, cancelled: cancelled))
        }
      }
    } onCancel: {
      cancelled.store(true, ordering: .relaxed)
    }
    switch result {
    case .success(let samples): return samples
    case .failure(let error): throw error
    }
  }

  // MARK: Private

  private static let queue = DispatchQueue(
    label: "com.sazuyakun.shades.audio-decode",
    qos: .utility,
    attributes: .concurrent,
  )
  /// Frames read per chunk.
  private static let chunk = 32768

  /// The blocking part: reads the file through ExtAudioFile, which converts it to mono `Float`s
  /// at `sampleRate` as it reads.
  private static func decode(
    _ url: URL,
    sampleRate: Double,
    cancelled: borrowing Atomic<Bool>,
  ) -> Result<[Float], MediaError> {
    var opened: ExtAudioFileRef?
    guard ExtAudioFileOpenURL(url as CFURL, &opened) == noErr, let file = opened else {
      logger.error("samples.failed reason=open path=\(url.path, privacy: .private)")
      return .failure(.unreadable(url))
    }
    defer { ExtAudioFileDispose(file) }
    var format = AudioStreamBasicDescription(
      mSampleRate: sampleRate,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 4,
      mFramesPerPacket: 1,
      mBytesPerFrame: 4,
      mChannelsPerFrame: 1,
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
    var buffer = [Float](repeating: 0, count: chunk)
    while true {
      guard !cancelled.load(ordering: .relaxed) else {
        return .failure(.cancelled(url))
      }
      var frames = UInt32(chunk)
      let status = buffer.withUnsafeMutableBytes { bytes -> OSStatus in
        var list = AudioBufferList(
          mNumberBuffers: 1,
          mBuffers: AudioBuffer(
            mNumberChannels: 1,
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
        return .success(samples)
      }
      samples.append(contentsOf: buffer.prefix(Int(frames)))
    }
  }

}
