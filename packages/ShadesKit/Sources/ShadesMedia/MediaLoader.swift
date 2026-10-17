import AVFoundation
import ShadesCore

/// Reads what Shades needs to know about a media file on disk.
public enum MediaLoader {
  /// Reads a video or audio file's duration, size and whether it has picture and sound.
  public static func load(_ url: URL) async throws(MediaError) -> Media {
    guard FileManager.default.fileExists(atPath: url.path) else {
      logger.error("load.failed reason=fileMissing path=\(url.path, privacy: .private)")
      throw .fileMissing(url)
    }
    let asset = AVURLAsset(url: url)
    let duration: CMTime
    let videoTracks: [AVAssetTrack]
    let audioTracks: [AVAssetTrack]
    do {
      duration = try await asset.load(.duration)
      videoTracks = try await asset.loadTracks(withMediaType: .video)
      audioTracks = try await asset.loadTracks(withMediaType: .audio)
    } catch {
      logger.error("load.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    guard let videoTrack = videoTracks.first else {
      guard !audioTracks.isEmpty else {
        logger.error("load.failed reason=noPictureOrSound path=\(url.path, privacy: .private)")
        throw .noPictureOrSound(url)
      }
      return Media(
        url: url,
        duration: MediaTime(value: duration.value, timescale: duration.timescale),
        width: 0,
        height: 0,
        hasVideo: false,
        hasAudio: true,
      )
    }
    let size: CGSize
    do {
      let (naturalSize, transform) = try await videoTrack.load(.naturalSize, .preferredTransform)
      size = naturalSize.applying(transform)
    } catch {
      logger.error("load.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    return Media(
      url: url,
      duration: MediaTime(value: duration.value, timescale: duration.timescale),
      width: Int(abs(size.width)),
      height: Int(abs(size.height)),
      hasAudio: !audioTracks.isEmpty,
    )
  }

  /// Makes a still image from early in the file, no larger than `maxSize`.
  public static func thumbnail(for url: URL, maxSize: CGSize) async throws(MediaError) -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maxSize
    do {
      return try await generator.image(at: CMTime(value: 1, timescale: 2)).image
    } catch {
      logger.error("thumbnail.failed path=\(url.path, privacy: .private)")
      throw .thumbnailFailed(url)
    }
  }
}
