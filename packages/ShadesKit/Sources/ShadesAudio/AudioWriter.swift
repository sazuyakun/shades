import AVFoundation

/// Writes mono samples to an AAC `.m4a` file.
public enum AudioWriter {

  // MARK: Public

  /// Writes `samples` (mono, at `sampleRate`) to `url`, replacing any file there. Encoding blocks,
  /// so it runs on a dispatch queue.
  public static func writeM4A(
    _ samples: [Float],
    sampleRate: Double,
    to url: URL,
  ) async throws(AudioError) {
    let result = await withCheckedContinuation { continuation in
      queue.async {
        continuation.resume(returning: Result { () throws(AudioError) in
          try write(samples, sampleRate: sampleRate, to: url)
        })
      }
    }
    try result.get()
  }

  // MARK: Private

  private static let queue = DispatchQueue(label: "com.sazuyakun.shades.audiowriter", qos: .utility)

  private static func write(
    _ samples: [Float],
    sampleRate: Double,
    to url: URL,
  ) throws(AudioError) {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      // why: there may be no earlier file; that's the common case.
      try? FileManager.default.removeItem(at: url)
      let file = try AVAudioFile(
        forWriting: url,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: sampleRate,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 160_000,
        ],
        commonFormat: .pcmFormatFloat32,
        interleaved: false,
      )
      let chunk = 32768
      var start = 0
      while start < samples.count {
        let count = min(chunk, samples.count - start)
        guard
          let buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(count),
          ),
          let channel = buffer.floatChannelData?[0]
        else {
          throw AudioError.unwritable(url)
        }
        samples.withUnsafeBufferPointer { source in
          if let base = source.baseAddress {
            channel.update(from: base + start, count: count)
          }
        }
        buffer.frameLength = AVAudioFrameCount(count)
        try file.write(from: buffer)
        start += count
      }
    } catch let error as AudioError {
      throw error
    } catch {
      logger.error("audio.writeFailed path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

}
