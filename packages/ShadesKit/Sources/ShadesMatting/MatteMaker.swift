import AVFoundation

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
      let current = (mask ?? [UInt8](repeating: 0, count: width * height)).map(Float.init)
      // why: blending with the last frame steadies a mask that would otherwise shimmer.
      let blended = smoothed
        .map { previous in zip(current, previous).map { 0.65 * $0 + 0.35 * $1 } } ?? current
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
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
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
    CVPixelBufferLockBaseAddress(buffer, [])
    if let base = CVPixelBufferGetBaseAddress(buffer) {
      let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
      let pixels = base.assumingMemoryBound(to: UInt8.self)
      for row in 0 ..< height {
        for column in 0 ..< width {
          let value = UInt8(min(max(mask[row * width + column], 0), 255))
          let offset = row * rowBytes + column * 4
          pixels[offset] = value
          pixels[offset + 1] = value
          pixels[offset + 2] = value
          pixels[offset + 3] = 255
        }
      }
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
