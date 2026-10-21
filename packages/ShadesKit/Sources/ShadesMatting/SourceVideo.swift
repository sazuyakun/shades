import AVFoundation

/// A video file to analyse: its length, the frame rate it's read at, its shape, and its frames.
struct SourceVideo {

  let asset: AVURLAsset
  /// Seconds.
  let duration: Double
  /// The rate frames are read at: the file's own, at most 30.
  let frameRate: Double
  /// The frames' size as stored in the file.
  let storedSize: CGSize
  /// The frames' size once turned upright (portrait iPhone video is stored sideways).
  let uprightSize: CGSize

  /// One moment for every frame read, from the start.
  var frameTimes: [CMTime] {
    let count = max(1, Int(duration * frameRate))
    return (0 ..< count).map { CMTime(value: CMTimeValue($0), timescale: CMTimeScale(frameRate)) }
  }

  /// Reads the video at `url`'s description.
  static func load(_ url: URL) async throws(MattingError) -> SourceVideo {
    let asset = AVURLAsset(url: url)
    do {
      guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        logger.error("source.failed reason=noVideo path=\(url.path, privacy: .private)")
        throw MattingError.unreadable(url)
      }
      let (duration, rate, size, transform) = try await (
        asset.load(.duration),
        track.load(.nominalFrameRate),
        track.load(.naturalSize),
        track.load(.preferredTransform),
      )
      let upright = CGRect(origin: .zero, size: size).applying(transform).size
      return SourceVideo(
        asset: asset,
        duration: duration.seconds,
        frameRate: Double(min(max(rate, 1), 30)).rounded(),
        storedSize: size,
        uprightSize: CGSize(width: abs(upright.width), height: abs(upright.height)),
      )
    } catch let error as MattingError {
      throw error
    } catch {
      logger.error("source.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
  }

  /// Hands back frames no bigger than `maximumSide`, turned `upright` or as stored, each the
  /// nearest to the moment asked for.
  func generator(maximumSide: Int, upright: Bool) -> AVAssetImageGenerator {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = upright
    generator.maximumSize = CGSize(width: maximumSide, height: maximumSide)
    let tolerance = CMTime(value: 1, timescale: CMTimeScale(frameRate * 2))
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance
    return generator
  }

}
