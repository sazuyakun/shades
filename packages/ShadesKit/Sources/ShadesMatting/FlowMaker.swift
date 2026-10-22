import AVFoundation
import ShadesCore
import ShadesMedia

/// Makes a video's optical flow for footage motion blur: a small video, frame for frame with the
/// source and in its stored orientation, whose red and green say how fast each pixel moves (see
/// `FlowVideo`). Playback reads it like any other track, so nothing is measured while playing.
public enum FlowMaker {

  // MARK: Public

  /// How wide flow videos are, in pixels; motion is smooth, so this is plenty.
  public static let width = 320

  /// Writes the optical flow of the video at `url` to `destination`.
  @concurrent
  public static func make(
    from url: URL,
    to destination: URL,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(MattingError) {
    let source = try await SourceVideo.load(url)
    let stored = source.storedSize
    let height = max(2, Int((Double(width) * stored.height / stored.width / 2).rounded()) * 2)
    let writer = try FrameWriter(
      url: destination,
      width: width,
      height: height,
      pixelFormat: kCVPixelFormatType_32BGRA,
    )
    let times = source.frameTimes
    var previous: (image: CGImage, time: CMTime)?
    var written = 0
    // why: Vision's flow is accurate enough at this size and much faster than at full size.
    let generator = source.generator(maximumSide: 512, upright: false)
    for await frame in generator.images(for: times) {
      guard !Task.isCancelled else {
        writer.cancel()
        throw .cancelled
      }
      guard let image = try? frame.image else {
        // why: a frame that won't decode is skipped; the next one measures across the gap.
        continue
      }
      if let previous {
        let bytes = try await estimate(
          from: previous.image,
          to: image,
          interval: (frame.requestedTime - previous.time).seconds,
          height: height,
        )
        // why: the first frame has nothing before it, so it moves as the second one does.
        let moments = written == 0 ? [previous.time, frame.requestedTime] : [frame.requestedTime]
        for moment in moments {
          try await writer.append(at: moment) { fill($0, with: bytes, height: height) }
          written += 1
        }
      }
      previous = (image, frame.requestedTime)
      progress(Double(written) / Double(times.count))
      await JobQueue.pausePoint()
    }
    if written == 0, let previous {
      let still = [UInt8](repeating: 128, count: width * height * 4)
      try await writer.append(at: previous.time) { fill($0, with: still, height: height) }
    }
    try await writer.finish()
  }

  // MARK: Private

  private static let queue = DispatchQueue(label: "com.sazuyakun.shades.flow", qos: .utility)

  /// Runs Vision on a dispatch queue: it blocks while it measures.
  private static func estimate(
    from previous: CGImage,
    to current: CGImage,
    interval: Double,
    height: Int,
  ) async throws(MattingError) -> [UInt8] {
    let result = await withCheckedContinuation { continuation in
      queue.async {
        continuation.resume(returning: Result { () throws(MattingError) in
          try FlowEstimator.frame(
            from: previous,
            to: current,
            interval: interval,
            width: width,
            height: height,
          )
        })
      }
    }
    return try result.get()
  }

  /// Copies BGRA `bytes` row by row into the locked frame.
  private static func fill(_ buffer: CVPixelBuffer, with bytes: [UInt8], height: Int) {
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
      return
    }
    let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
    bytes.withUnsafeBytes { source in
      guard let start = source.baseAddress else {
        return
      }
      for row in 0 ..< height {
        (base + row * rowBytes).copyMemory(from: start + row * width * 4, byteCount: width * 4)
      }
    }
  }

}
