import Accelerate
import AVFoundation
import ShadesCore

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
    let asset = AVURLAsset(url: url)
    let (duration, frameRate, upright) = try await describe(asset, url: url)
    let height = max(2, Int((Double(width) * upright.height / upright.width / 2).rounded()) * 2)
    let writer = try makeWriter(to: destination, width: width, height: height)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1024, height: 1024)
    let tolerance = CMTime(value: 1, timescale: CMTimeScale(frameRate * 2))
    generator.requestedTimeToleranceBefore = tolerance
    generator.requestedTimeToleranceAfter = tolerance
    let count = max(1, Int(duration * frameRate))
    let times = (0 ..< count)
      .map { CMTime(value: CMTimeValue($0), timescale: CMTimeScale(frameRate)) }
    var smoothed: [Float]?
    var index = 0
    for await frame in generator.images(for: times) {
      guard !Task.isCancelled else {
        writer.writer.cancelWriting()
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
      try await writer.append(blended, at: frame.requestedTime)
      index += 1
      progress(Double(index) / Double(count))
    }
    try await writer.finish()
  }

  // MARK: Private

  private static let queue = DispatchQueue(label: "com.sazuyakun.shades.matting", qos: .utility)

  /// The video's length (seconds), the frame rate to sample at (at most 30) and its upright size.
  private static func describe(
    _ asset: AVURLAsset,
    url: URL,
  ) async throws(MattingError) -> (Double, Double, CGSize) {
    do {
      guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        logger.error("matte.failed reason=noVideo path=\(url.path, privacy: .private)")
        throw MattingError.unreadable(url)
      }
      let (duration, rate, size, transform) = try await (
        asset.load(.duration),
        track.load(.nominalFrameRate),
        track.load(.naturalSize),
        track.load(.preferredTransform),
      )
      let upright = CGRect(origin: .zero, size: size).applying(transform).size
      return (
        duration.seconds,
        Double(min(max(rate, 1), 30)).rounded(),
        CGSize(width: abs(upright.width), height: abs(upright.height)),
      )
    } catch let error as MattingError {
      throw error
    } catch {
      logger.error("matte.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
  }

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

  private static func makeWriter(
    to destination: URL,
    width: Int,
    height: Int,
  ) throws(MattingError) -> MatteWriter {
    do {
      try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      // why: there may be no old matte; that's the common case.
      try? FileManager.default.removeItem(at: destination)
      return try MatteWriter(url: destination, width: width, height: height)
    } catch {
      logger.error("matte.failed reason=writer path=\(destination.path, privacy: .private)")
      throw .unwritable(destination)
    }
  }

}

// MARK: - MatteWriter

/// Writes gray mask frames into a video file.
private struct MatteWriter {

  // MARK: Lifecycle

  init(url: URL, width: Int, height: Int) throws {
    self.url = url
    self.width = width
    self.height = height
    writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ],
    )
    writer.add(input)
    guard writer.startWriting() else {
      throw MattingError.unwritable(url)
    }
    writer.startSession(atSourceTime: .zero)
  }

  // MARK: Internal

  let writer: AVAssetWriter

  /// Appends one mask (0…255 per pixel) at `time`.
  func append(_ mask: [Float], at time: CMTime) async throws(MattingError) {
    while !input.isReadyForMoreMediaData {
      try? await Task.sleep(for: .milliseconds(2)) // why: a cancelled wait just polls again.
    }
    guard let pool = adaptor.pixelBufferPool else {
      throw .unwritable(url)
    }
    var made: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made)
    guard let buffer = made else {
      throw .unwritable(url)
    }
    let gray = vDSP.floatingPointToInteger(
      vDSP.clip(mask, to: 0 ... 255),
      integerType: UInt8.self,
      rounding: .towardNearestInteger,
    )
    CVPixelBufferLockBaseAddress(buffer, [])
    // why: a gray mask is just the brightness plane; colour stays neutral (128).
    if
      let luma = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
      let chroma = CVPixelBufferGetBaseAddressOfPlane(buffer, 1)
    {
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
    CVPixelBufferUnlockBaseAddress(buffer, [])
    guard adaptor.append(buffer, withPresentationTime: time) else {
      logger.error("matte.failed reason=append path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  /// Closes the file.
  func finish() async throws(MattingError) {
    input.markAsFinished()
    let writer = writer
    await withCheckedContinuation { continuation in
      writer.finishWriting { continuation.resume() }
    }
    guard writer.status == .completed else {
      logger.error("matte.failed reason=finish path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  // MARK: Private

  private let url: URL
  private let width: Int
  private let height: Int
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor

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
