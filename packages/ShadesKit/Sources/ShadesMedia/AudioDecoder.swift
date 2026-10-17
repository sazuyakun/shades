import AVFoundation

/// Decodes the sound of any audio or video file into mono samples at a chosen rate, for speech
/// recognition and audio analysis. All sound tracks are mixed. Ported from Nebula.
public enum AudioDecoder {

  /// The file's sound as mono samples from -1 to 1, `sampleRate` per second.
  @concurrent
  public static func mono(from url: URL, sampleRate: Double) async throws(MediaError) -> [Float] {
    let asset = AVURLAsset(url: url)
    let tracks: [AVAssetTrack]
    do {
      tracks = try await asset.loadTracks(withMediaType: .audio)
    } catch {
      logger.error("samples.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    guard !tracks.isEmpty else {
      logger.error("samples.failed reason=noAudio path=\(url.path, privacy: .private)")
      throw .noAudio(url)
    }
    let reader: AVAssetReader
    do {
      reader = try AVAssetReader(asset: asset)
    } catch {
      logger.error("samples.failed reason=reader path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ])
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      logger.error("samples.failed reason=format path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    reader.add(output)
    guard reader.startReading() else {
      logger.error("samples.failed reason=start path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    var samples = [Float]()
    while let buffer = output.copyNextSampleBuffer() {
      guard !Task.isCancelled else {
        reader.cancelReading()
        throw .cancelled(url)
      }
      guard let block = CMSampleBufferGetDataBuffer(buffer) else {
        continue
      }
      let count = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
      let offset = samples.count
      samples.append(contentsOf: repeatElement(0, count: count))
      let status = samples.withUnsafeMutableBytes { bytes -> OSStatus in
        guard let base = bytes.baseAddress else {
          return kCMBlockBufferBadPointerParameterErr
        }
        return CMBlockBufferCopyDataBytes(
          block,
          atOffset: 0,
          dataLength: count * MemoryLayout<Float>.size,
          destination: base + offset * MemoryLayout<Float>.size,
        )
      }
      guard status == kCMBlockBufferNoErr else {
        reader.cancelReading()
        logger.error("samples.failed reason=copy status=\(status, privacy: .public)")
        throw .unreadable(url)
      }
    }
    guard reader.status != .failed else {
      logger.error("samples.failed reason=read path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    return samples
  }

}
