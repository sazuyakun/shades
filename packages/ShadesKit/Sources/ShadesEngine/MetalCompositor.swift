import AVFoundation

// MARK: - MetalCompositor

/// AVFoundation's hook into our renderer: it asks this compositor for every frame it plays or
/// exports, so preview and export are drawn by the same Metal code.
final class MetalCompositor: NSObject, AVVideoCompositing {

  // MARK: Lifecycle

  override init() {
    do {
      renderer = try MetalRenderer()
    } catch {
      // why: AVFoundation creates this class itself, so setup failure is reported per frame.
      renderer = nil
    }
  }

  // MARK: Internal

  let sourcePixelBufferAttributes: [String: any Sendable]? = pixelBufferAttributes
  let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = pixelBufferAttributes

  func renderContextChanged(_: AVVideoCompositionRenderContext) { }

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    guard
      let renderer,
      let instruction = request.videoCompositionInstruction as? CompositionInstruction,
      let output = request.renderContext.newPixelBuffer()
    else {
      logger.error("frame.renderFailed reason=missingInput")
      request.finish(with: EngineError.renderFailed)
      return
    }
    do {
      // why: there's no source frame in a gap between clips; that's normal and draws black.
      try renderer.draw(request.sourceFrame(byTrackID: instruction.trackID), into: output)
    } catch {
      request.finish(with: error)
      return
    }
    instruction.frameCounter.recordFrame()
    request.finish(withComposedVideoFrame: output)
  }

  // MARK: Private

  private let renderer: MetalRenderer?

}

/// 8-bit BGRA, readable by Metal: the format every frame uses on its way through the compositor.
private let pixelBufferAttributes: [String: any Sendable] = [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferMetalCompatibilityKey as String: true,
]
