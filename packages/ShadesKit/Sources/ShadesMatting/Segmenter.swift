import CoreImage
import CoreVideo
import Foundation
import Vision

/// Finds the subject in one picture and returns its mask as gray bytes (255 = subject), sized
/// `width`×`height`. Runs Vision synchronously, so callers keep it off Swift's thread pool.
enum Segmenter {

  // MARK: Internal

  /// The subject mask of `image`, or `nil` when nothing was found.
  static func mask(
    of image: CGImage,
    engine: MatteEngine,
    width: Int,
    height: Int,
  ) throws(MattingError) -> [UInt8]? {
    let handler = VNImageRequestHandler(cgImage: image)
    let buffer: CVPixelBuffer?
    do {
      switch engine {
      case .visionPerson:
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try handler.perform([request])
        buffer = request.results?.first?.pixelBuffer

      case .visionForeground:
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first else {
          return nil
        }
        buffer = try observation.generateScaledMaskForImage(
          forInstances: observation.allInstances,
          from: handler,
        )
      }
    } catch {
      logger.error("segment.failed engine=\(engine.rawValue, privacy: .public)")
      throw .segmentationFailed
    }
    return buffer.map { resized($0, width: width, height: height) }
  }

  // MARK: Private

  /// The mask scaled to `width`×`height` as one byte per pixel.
  private static func resized(_ mask: CVPixelBuffer, width: Int, height: Int) -> [UInt8] {
    let image = CIImage(cvPixelBuffer: mask)
    let scaled = image.transformed(by: CGAffineTransform(
      scaleX: CGFloat(width) / image.extent.width,
      y: CGFloat(height) / image.extent.height,
    ))
    var bytes = [UInt8](repeating: 0, count: width * height)
    let context = CIContext(options: [.workingColorSpace: NSNull()])
    bytes.withUnsafeMutableBytes { buffer in
      guard let base = buffer.baseAddress else {
        return
      }
      context.render(
        scaled,
        toBitmap: base,
        rowBytes: width,
        bounds: CGRect(x: 0, y: 0, width: width, height: height),
        format: .L8,
        colorSpace: nil,
      )
    }
    return bytes
  }

}
