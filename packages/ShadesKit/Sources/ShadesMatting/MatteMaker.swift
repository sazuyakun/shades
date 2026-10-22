import Accelerate
import AVFoundation
import ShadesCore
import ShadesMedia

// MARK: - MatteMaker

/// Makes a clip's cut-out: a small gray video, upright, frame for frame with the source, white
/// where the subject is. Playback reads it like any other track, so no model runs while playing.
public enum MatteMaker {

  // MARK: Public

  /// How wide mattes are, in pixels; plenty for soft cut-out edges, light to store and play.
  public static let width = 640

  /// Writes the matte of the video at `url` to `destination`, finding the subject with `engine`.
  @concurrent
  public static func make(
    from url: URL,
    to destination: URL,
    engine: MatteEngine,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(MattingError) {
    let source = try await SourceVideo.load(url)
    let upright = source.uprightSize
    let height = max(2, Int((Double(width) * upright.height / upright.width / 2).rounded()) * 2)
    let writer = try FrameWriter(
      url: destination,
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
    )
    let times = source.frameTimes
    var smoothed: [Float]?
    var index = 0
    for await frame in source.generator(maximumSide: 1024, upright: true).images(for: times) {
      guard !Task.isCancelled else {
        writer.cancel()
        throw .cancelled
      }
      guard let image = try? frame.image else {
        // why: a frame that won't decode keeps the last mask instead of failing the clip.
        continue
      }
      let mask = try await segment(image, engine: engine, width: width, height: height)
      let current = vDSP.integerToFloatingPoint(
        mask ?? [UInt8](repeating: 0, count: width * height),
        floatingPointType: Float.self,
      )
      // why: blending with the last frame steadies a mask that would otherwise shimmer.
      let blended = smoothed.map { previous in
        vDSP.add(vDSP.multiply(0.65, current), vDSP.multiply(0.35, previous))
      } ?? current
      smoothed = blended
      let gray = vDSP.floatingPointToInteger(
        vDSP.clip(blended, to: 0 ... 255),
        integerType: UInt8.self,
        rounding: .towardNearestInteger,
      )
      try await writer.append(at: frame.requestedTime) { buffer in
        fillGray(buffer, with: gray, width: width, height: height)
      }
      index += 1
      progress(Double(index) / Double(times.count))
      await JobQueue.pausePoint()
    }
    try await writer.finish()
  }

  // MARK: Private

  private static let queue = DispatchQueue(label: "com.sazuyakun.shades.matting", qos: .utility)

  /// Runs Vision on a dispatch queue: it blocks while the model runs.
  private static func segment(
    _ image: CGImage,
    engine: MatteEngine,
    width: Int,
    height: Int,
  ) async throws(MattingError) -> [UInt8]? {
    let result = await withCheckedContinuation { continuation in
      queue.async {
        continuation.resume(returning: Result { () throws(MattingError) in
          try Segmenter.mask(of: image, engine: engine, width: width, height: height)
        })
      }
    }
    return try result.get()
  }

  /// Writes a gray mask into a bi-planar frame: it's just the brightness plane, with colour left
  /// neutral (128).
  private static func fillGray(
    _ buffer: CVPixelBuffer,
    with gray: [UInt8],
    width: Int,
    height: Int,
  ) {
    guard
      let luma = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
      let chroma = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
    else {
      return
    }
    let lumaRowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
    gray.withUnsafeBytes { source in
      guard let start = source.baseAddress else {
        return
      }
      for row in 0 ..< height {
        (luma + row * lumaRowBytes).copyMemory(from: start + row * width, byteCount: width)
      }
    }
    let chromaBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
      * CVPixelBufferGetHeightOfPlane(buffer, 1)
    memset(chroma, 128, chromaBytes)
  }

}

// MARK: - MatteMaker + Subject

extension MatteMaker {

  // MARK: Public

  /// Where the subject is over time: the centre of the cut-out's white area every `step`
  /// seconds, as fractions of the picture. Moments with no subject are skipped.
  @concurrent
  public static func subjectPath(
    of matte: URL,
    every step: Double = 0.5,
  ) async throws(MattingError) -> [SubjectPoint] {
    let asset = AVURLAsset(url: matte)
    let duration: Double
    do {
      duration = try await asset.load(.duration).seconds
    } catch {
      logger.error("subject.failed reason=unreadable path=\(matte.path, privacy: .private)")
      throw .unreadable(matte)
    }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.maximumSize = CGSize(width: 160, height: 160)
    let times = stride(from: 0, to: duration, by: step).map { CMTime(
      seconds: $0,
      preferredTimescale: 600,
    ) }
    var path = [SubjectPoint]()
    for await frame in generator.images(for: times) {
      // why: an unreadable frame just leaves a gap in the path.
      guard let image = try? frame.image, let center = centroid(of: image) else {
        continue
      }
      path.append(SubjectPoint(
        time: MediaTime(seconds: frame.requestedTime.seconds, timescale: 1000),
        x: center.x,
        y: center.y,
      ))
    }
    return path
  }

  // MARK: Private

  /// The brightness-weighted centre of a gray picture, or `nil` when it's empty.
  private static func centroid(of image: CGImage) -> (x: Double, y: Double)? {
    let width = image.width
    let height = image.height
    var gray = [UInt8](repeating: 0, count: width * height)
    let drawn = gray.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue,
        )
      else {
        return false
      }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else {
      return nil
    }
    var total = 0.0
    var sumX = 0.0
    var sumY = 0.0
    for row in 0 ..< height {
      for column in 0 ..< width {
        let weight = Double(gray[row * width + column]) / 255
        guard weight > 0.5 else {
          continue
        }
        total += weight
        sumX += weight * (Double(column) + 0.5)
        sumY += weight * (Double(row) + 0.5)
      }
    }
    guard total > Double(width * height) * 0.002 else {
      return nil
    }
    return (sumX / total / Double(width), sumY / total / Double(height))
  }

}
