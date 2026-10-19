import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Turns the subject of one video frame into a sticker: a PNG of just the subject, on a
/// see-through background, cropped close around it.
public enum StickerMaker {

  // MARK: Public

  /// Writes the subject of the video at `url`, `seconds` in, to `destination` as a PNG.
  @concurrent
  public static func cutout(
    from url: URL,
    at seconds: Double,
    engine: MatteEngine,
    to destination: URL,
  ) async throws(MattingError) {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1600, height: 1600)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let frame: CGImage
    do {
      frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    } catch {
      logger.error("sticker.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    let mask = try await segment(frame, engine: engine)
    guard let mask else {
      logger.error("sticker.failed reason=noSubject")
      throw .segmentationFailed
    }
    try write(frame, mask: mask, to: destination)
  }

  // MARK: Private

  private static let queue = DispatchQueue(
    label: "com.sazuyakun.shades.sticker",
    qos: .userInitiated,
  )
  private static let context = CIContext()

  /// Runs Vision on a dispatch queue: it blocks while the model runs.
  private static func segment(
    _ image: CGImage,
    engine: MatteEngine,
  ) async throws(MattingError) -> [UInt8]? {
    let result = await withCheckedContinuation { continuation in
      queue.async {
        continuation.resume(returning: Result { () throws(MattingError) in
          try Segmenter.mask(of: image, engine: engine, width: image.width, height: image.height)
        })
      }
    }
    return try result.get()
  }

  /// The frame where the mask is white, cropped to the subject with a little room.
  private static func write(
    _ frame: CGImage,
    mask: [UInt8],
    to destination: URL,
  ) throws(MattingError) {
    let width = frame.width
    let height = frame.height
    let maskImage = CIImage(
      bitmapData: Data(mask),
      bytesPerRow: width,
      size: CGSize(width: width, height: height),
      format: .L8,
      colorSpace: nil,
    )
    let cut = CIImage(cgImage: frame).applyingFilter("CIBlendWithMask", parameters: [
      kCIInputBackgroundImageKey: CIImage.empty(),
      kCIInputMaskImageKey: maskImage,
    ])
    guard let bounds = subjectBounds(mask, width: width, height: height) else {
      logger.error("sticker.failed reason=noSubject")
      throw .segmentationFailed
    }
    do {
      try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      try context.writePNGRepresentation(
        of: cut.cropped(to: bounds),
        to: destination,
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      )
    } catch {
      logger.error("sticker.failed reason=unwritable path=\(destination.path, privacy: .private)")
      throw .unwritable(destination)
    }
  }

  /// The box around the mask's subject (CoreImage's bottom-left origin), padded by 4%, or `nil`
  /// when the mask is empty.
  private static func subjectBounds(_ mask: [UInt8], width: Int, height: Int) -> CGRect? {
    var minX = width
    var maxX = -1
    var minY = height
    var maxY = -1
    for row in 0 ..< height {
      for column in 0 ..< width where mask[row * width + column] > 127 {
        minX = min(minX, column)
        maxX = max(maxX, column)
        minY = min(minY, row)
        maxY = max(maxY, row)
      }
    }
    guard maxX >= minX, maxY >= minY else {
      return nil
    }
    let pad = Double(max(width, height)) * 0.04
    let box = CGRect(
      x: Double(minX),
      y: Double(height - 1 - maxY),
      width: Double(maxX - minX + 1),
      height: Double(maxY - minY + 1),
    )
    return box.insetBy(dx: -pad, dy: -pad).intersection(CGRect(
      x: 0,
      y: 0,
      width: width,
      height: height,
    ))
  }

}
