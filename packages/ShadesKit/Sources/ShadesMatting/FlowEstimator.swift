import CoreImage
import CoreVideo
import Foundation
import ShadesCore
import Vision

/// Measures how each pixel moves between two frames with Apple Vision's optical flow, as one
/// frame of a flow video. Runs Vision synchronously, so callers keep it off Swift's thread pool.
enum FlowEstimator {

  // MARK: Internal

  /// The motion from `previous` to `current`, `interval` seconds apart, as BGRA bytes sized
  /// `width`×`height`: red and green the speed across and down (see `FlowVideo`), blue neutral.
  static func frame(
    from previous: CGImage,
    to current: CGImage,
    interval: Double,
    width: Int,
    height: Int,
  ) throws(MattingError) -> [UInt8] {
    let request = VNGenerateOpticalFlowRequest(targetedCGImage: current)
    // why: on test motion revision 1 measures moves exactly and in 20–50 ms a frame; the newer
    // revision 2 reads them 2–4× too short and is slower.
    request.revision = VNGenerateOpticalFlowRequestRevision1
    request.computationAccuracy = .medium
    request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
    do {
      try VNImageRequestHandler(cgImage: previous).perform([request])
    } catch {
      logger.error("flow.failed reason=vision")
      throw .flowFailed
    }
    guard let flow = request.results?.first?.pixelBuffer else {
      logger.error("flow.failed reason=noResult")
      throw .flowFailed
    }
    return encoded(flow, interval: max(interval, 0.001), width: width, height: height)
  }

  // MARK: Private

  /// Shared across frames: making a CoreImage context is slow, and one is safe to share. No
  /// colour management, so stored speeds pass through untouched.
  private static let context = CIContext(options: [
    .workingColorSpace: NSNull(),
    .outputColorSpace: NSNull(),
  ])

  /// The flow (pixels moved, two floats a pixel) resampled to `width`×`height`, written as
  /// speeds in pictures a second and steadied.
  private static func encoded(
    _ flow: CVPixelBuffer,
    interval: Double,
    width: Int,
    height: Int,
  ) -> [UInt8] {
    var bytes = [UInt8](repeating: 128, count: width * height * 4)
    CVPixelBufferLockBaseAddress(flow, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(flow, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(flow) else {
      return bytes
    }
    let flowWidth = CVPixelBufferGetWidth(flow)
    let flowHeight = CVPixelBufferGetHeight(flow)
    let rowBytes = CVPixelBufferGetBytesPerRow(flow)
    let stored = { (speed: Double) in UInt8((FlowVideo.value(of: speed) * 255).rounded()) }
    for row in 0 ..< height {
      let vectors = (base + (row * flowHeight / height) * rowBytes)
        .assumingMemoryBound(to: Float.self)
      for column in 0 ..< width {
        let at = (column * flowWidth / width) * 2
        let pixel = (row * width + column) * 4
        bytes[pixel + 1] = stored(Double(vectors[at + 1]) / Double(flowHeight) / interval)
        bytes[pixel + 2] = stored(Double(vectors[at]) / Double(flowWidth) / interval)
        bytes[pixel + 3] = 255
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
