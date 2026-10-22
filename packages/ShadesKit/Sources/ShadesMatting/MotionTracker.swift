import AVFoundation
import ShadesCore
import ShadesMedia
import Vision

/// Follows something through a video, frame by frame, from a box drawn around it at one moment.
/// Vision blocks while it works, so the tracker runs on its own dispatch queue, never on Swift's
/// thread pool.
public actor MotionTracker {

  // MARK: Lifecycle

  private init(box: CGRect) {
    // why: Vision measures from the bottom left; Shades from the top left.
    last = VNDetectedObjectObservation(boundingBox: CGRect(
      x: box.minX,
      y: 1 - box.maxY,
      width: box.width,
      height: box.height,
    ))
  }

  // MARK: Public

  nonisolated public var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  /// The centre of what's inside `box` (fractions of the upright picture, top left origin) from
  /// `start` until `end` (seconds of the video at `url`), until it's lost from view.
  @concurrent
  public static func track(
    in url: URL,
    box: CGRect,
    from start: Double,
    to end: Double,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(MattingError) -> [SubjectPoint] {
    let asset = AVURLAsset(url: url)
    let rate: Float
    do {
      guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        logger.error("track.failed reason=noVideo path=\(url.path, privacy: .private)")
        throw MattingError.unreadable(url)
      }
      rate = try await track.load(.nominalFrameRate)
    } catch {
      logger.error("track.failed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    let step = 1 / Double(min(max(rate, 1), 30))
    let times = stride(from: start, to: end, by: step)
      .map { CMTime(seconds: $0, preferredTimescale: 600) }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 960, height: 960)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let tracker = MotionTracker(box: box)
    var path = [SubjectPoint]()
    for await frame in generator.images(for: times) {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      // why: a frame that won't decode is skipped; the tracker picks up on the next one.
      guard let image = try? frame.image else {
        continue
      }
      guard let center = await tracker.follow(into: image) else {
        break
      }
      path.append(SubjectPoint(
        time: MediaTime(seconds: frame.requestedTime.seconds, timescale: 1000),
        x: center.x,
        y: center.y,
      ))
      progress(Double(path.count) / Double(times.count))
      await JobQueue.pausePoint()
    }
    guard path.count > 1 else {
      logger.error("track.failed reason=lost path=\(url.path, privacy: .private)")
      throw .trackingFailed
    }
    return path
  }

  // MARK: Private

  private nonisolated let queue = DispatchSerialQueue(label: "com.sazuyakun.shades.tracking")
  private let handler = VNSequenceRequestHandler()
  private var last: VNDetectedObjectObservation

  /// Finds the tracked thing in the next frame; `nil` once it's lost.
  private func follow(into image: CGImage) -> (x: Double, y: Double)? {
    let request = VNTrackObjectRequest(detectedObjectObservation: last)
    request.trackingLevel = .accurate
    do {
      try handler.perform([request], on: image)
    } catch {
      // why: Vision fails a frame when the thing has left the picture; that's where tracking ends.
      return nil
    }
    guard let found = request.results?.first as? VNDetectedObjectObservation, found.confidence > 0.3
    else {
      return nil
    }
    last = found
    return (Double(found.boundingBox.midX), Double(1 - found.boundingBox.midY))
  }

}
