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

  /// The flow (pixels moved, two floats a pixel) resampled to `width`×`height` and written as
  /// speeds in pictures a second.
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
    let scale = { (value: Double) in UInt8((FlowVideo.value(of: value) * 255).rounded()) }
    for row in 0 ..< height {
      let sourceRow = base + (row * flowHeight / height) * rowBytes
      let vectors = sourceRow.assumingMemoryBound(to: Float.self)
      for column in 0 ..< width {
        let at = (column * flowWidth / width) * 2
        let across = Double(vectors[at]) / Double(flowWidth) / interval
        let down = Double(vectors[at + 1]) / Double(flowHeight) / interval
        let pixel = (row * width + column) * 4
        bytes[pixel + 1] = scale(down)
        bytes[pixel + 2] = scale(across)
        bytes[pixel + 3] = 255
      }
    }
    return bytes
  }

}
