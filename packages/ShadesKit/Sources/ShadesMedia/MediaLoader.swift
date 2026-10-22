import AVFoundation
import ImageIO
import ShadesCore
import UniformTypeIdentifiers

/// Reads what Shades needs to know about a media file on disk.
public enum MediaLoader {

  // MARK: Public

  /// Reads a video, audio or image file's duration, size and whether it has picture and sound.
  public static func load(_ url: URL) async throws(MediaError) -> Media {
    guard FileManager.default.fileExists(atPath: url.path) else {
      logger.error("load.failed reason=fileMissing path=\(url.path, privacy: .private)")
      throw .fileMissing(url)
    }
    if let still = still(at: url) {
      return still
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
    let formats: [CMFormatDescription]
    do {
      let (naturalSize, transform, descriptions) = try await videoTrack.load(
        .naturalSize,
        .preferredTransform,
        .formatDescriptions,
      )
      size = naturalSize.applying(transform)
      formats = descriptions
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
      color: formats.first.map(color),
    )
  }

  /// Makes a still image from early in the file (or of the image), no larger than `maxSize`.
  public static func thumbnail(for url: URL, maxSize: CGSize) async throws(MediaError) -> CGImage {
    if let image = image(at: url, maxSide: max(maxSize.width, maxSize.height)) {
      return image
    }
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

  /// `count` stills spread evenly through the file, no larger than `maxSize`, for hover-scrub.
  public static func filmstrip(
    for url: URL,
    count: Int,
    maxSize: CGSize,
  ) async throws(MediaError) -> [CGImage] {
    if let image = image(at: url, maxSide: max(maxSize.width, maxSize.height)) {
      return Array(repeating: image, count: count)
    }
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maxSize
    generator.requestedTimeToleranceBefore = .positiveInfinity
    generator.requestedTimeToleranceAfter = .positiveInfinity
    do {
      let duration = try await asset.load(.duration).seconds
      var frames = [CGImage]()
      for index in 0 ..< count {
        let seconds = duration * (Double(index) + 0.5) / Double(count)
        frames.append(try await generator.image(at: CMTime(
          seconds: seconds,
          preferredTimescale: 600,
        )).image)
      }
      return frames
    } catch {
      logger.error("filmstrip.failed path=\(url.path, privacy: .private)")
      throw .thumbnailFailed(url)
    }
  }

  // MARK: Private

  /// The colour tags of a video track's format.
  private static func color(of format: CMFormatDescription) -> VideoColor {
    let tag = { (key: CFString) in
      CMFormatDescriptionGetExtension(format, extensionKey: key) as? String
    }
    return VideoColor(
      primaries: tag(kCMFormatDescriptionExtension_ColorPrimaries),
      transfer: tag(kCMFormatDescriptionExtension_TransferFunction),
      matrix: tag(kCMFormatDescriptionExtension_YCbCrMatrix),
    )
  }

  /// The file as a still picture, when it's an image (PNG, JPEG, HEIC…).
  private static func still(at url: URL) -> Media? {
    guard
      let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return nil
    }
    let turned = (properties[kCGImagePropertyOrientation] as? Int).map { $0 >= 5 } ?? false
    return Media(
      url: url,
      duration: Media.stillLength,
      width: turned ? height : width,
      height: turned ? width : height,
      hasAudio: false,
      isStill: true,
    )
  }

  /// An image file decoded upright, no larger than `maxSide`, or `nil` if it isn't an image.
  private static func image(at url: URL, maxSide: Double) -> CGImage? {
    guard
      let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image),
      let source = CGImageSourceCreateWithURL(url as CFURL, nil)
    else {
      return nil
    }
    return CGImageSourceCreateThumbnailAtIndex(source, 0, [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxSide,
    ] as CFDictionary)
  }

}
