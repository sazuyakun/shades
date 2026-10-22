import CoreImage
import CoreVideo
import Foundation
import ShadesCore
import Vision

// MARK: - FlowEstimator

/// Measures how each pixel moves between two frames with Apple Vision's optical flow, as one
/// frame of a flow video. Runs Vision synchronously, so callers keep it off Swift's thread pool.
enum FlowEstimator {

  // MARK: Internal

  /// The motion from `previous` to `current`, `interval` seconds apart, as BGRA bytes sized
  /// `width`×`height`: red and green the speed across and down (see `FlowVideo`), blue neutral.
  /// Motion that the flow measured back from `current` doesn't undo is stored as still.
  static func frame(
    from previous: CGImage,
    to current: CGImage,
    interval: Double,
    width: Int,
    height: Int,
  ) throws(MattingError) -> [UInt8] {
    let forward = try flow(from: previous, to: current)
    let backward = try flow(from: current, to: previous)
    return encoded(
      forward,
      checkedBy: backward,
      interval: max(interval, 0.001),
      width: width,
      height: height,
    )
  }

  // MARK: Private

  /// Shared across frames: making a CoreImage context is slow, and one is safe to share. No
  /// colour management, so stored speeds pass through untouched.
  private static let context = CIContext(options: [
    .workingColorSpace: NSNull(),
    .outputColorSpace: NSNull(),
  ])

  /// Vision's optical flow from `from` to `to`: pixels moved, two floats a pixel.
  private static func flow(from: CGImage, to: CGImage) throws(MattingError) -> CVPixelBuffer {
    let request = VNGenerateOpticalFlowRequest(targetedCGImage: to)
    // why: on test motion revision 1 measures moves exactly and in 20–50 ms a frame; the newer
    // revision 2 reads them 2–4× too short and is slower.
    request.revision = VNGenerateOpticalFlowRequestRevision1
    request.computationAccuracy = .medium
    request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
    do {
      try VNImageRequestHandler(cgImage: from).perform([request])
    } catch {
      logger.error("flow.failed reason=vision")
      throw .flowFailed
    }
    guard let flow = request.results?.first?.pixelBuffer else {
      logger.error("flow.failed reason=noResult")
      throw .flowFailed
    }
    return flow
  }

  /// The `forward` flow resampled to `width`×`height`, written as speeds in pictures a second
  /// and steadied. Where following it and then the `backward` flow doesn't lead back to the
  /// start, Vision has guessed (the flat inside of a moving shape, its corners), so that motion
  /// is stored as still rather than smearing the picture the wrong way.
  private static func encoded(
    _ forward: CVPixelBuffer,
    checkedBy backward: CVPixelBuffer,
    interval: Double,
    width: Int,
    height: Int,
  ) -> [UInt8] {
    var bytes = [UInt8](repeating: 128, count: width * height * 4)
    guard let there = FlowField(forward), let back = FlowField(backward) else {
      return bytes
    }
    defer {
      there.unlock()
      back.unlock()
    }
    let stored = { (speed: Double) in UInt8((FlowVideo.value(of: speed) * 255).rounded()) }
    for row in 0 ..< height {
      for column in 0 ..< width {
        let x = column * there.width / width
        let y = row * there.height / height
        let move = there.vector(x: x, y: y)
        let home = back.vector(
          x: x + Int(move.x.rounded()),
          y: y + Int(move.y.rounded()),
        )
        let pixel = (row * width + column) * 4
        bytes[pixel + 3] = 255
        let miss = (move.x + home.x) * (move.x + home.x) + (move.y + home.y) * (move.y + home.y)
        let size = move.x * move.x + move.y * move.y + home.x * home.x + home.y * home.y
        // why: the usual forward–backward test: a miss of over a tenth of the motion, or over
        // about a pixel when barely moving, means the vectors don't agree.
        guard miss <= 0.01 * size + 0.5 else {
          continue
        }
        bytes[pixel + 1] = stored(Double(move.y) / Double(there.height) / interval)
        bytes[pixel + 2] = stored(Double(move.x) / Double(there.width) / interval)
      }
    }
    return steadied(bytes, width: width, height: height)
  }

  /// BGRA `bytes` with each channel replaced by the median of its 3×3 neighbourhood: Vision's
  /// odd stray vectors at edges would otherwise smear the picture sideways. A median only picks
  /// values already there, so the stored speeds stay exact.
  private static func steadied(_ bytes: [UInt8], width: Int, height: Int) -> [UInt8] {
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let image = CIImage(
      bitmapData: Data(bytes),
      bytesPerRow: width * 4,
      size: bounds.size,
      format: .BGRA8,
      colorSpace: nil,
    )
    .clampedToExtent()
    .applyingFilter("CIMedianFilter")
    var steadied = bytes
    steadied.withUnsafeMutableBytes { buffer in
      guard let base = buffer.baseAddress else {
        return
      }
      context.render(
        image,
        toBitmap: base,
        rowBytes: width * 4,
        bounds: bounds,
        format: .BGRA8,
        colorSpace: nil,
      )
    }
    return steadied
  }

}

// MARK: - FlowField

/// A flow buffer locked for reading: the vector (pixels moved) at any pixel, clamped to its
/// edges.
private struct FlowField {

  // MARK: Lifecycle

  /// Locks `buffer`; `nil` when it has no memory to read.
  init?(_ buffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
      return nil
    }
    self.buffer = buffer
    self.base = base
    width = CVPixelBufferGetWidth(buffer)
    height = CVPixelBufferGetHeight(buffer)
    rowBytes = CVPixelBufferGetBytesPerRow(buffer)
  }

  // MARK: Internal

  let width: Int
  let height: Int

  func vector(x: Int, y: Int) -> (x: Float, y: Float) {
    let row = (base + min(max(y, 0), height - 1) * rowBytes).assumingMemoryBound(to: Float.self)
    let at = min(max(x, 0), width - 1) * 2
    return (row[at], row[at + 1])
  }

  func unlock() {
    CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  }

  // MARK: Private

  private let buffer: CVPixelBuffer
  private let base: UnsafeMutableRawPointer
  private let rowBytes: Int

}
