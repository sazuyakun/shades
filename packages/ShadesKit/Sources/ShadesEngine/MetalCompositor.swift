import AVFoundation

// MARK: - MetalCompositor

/// AVFoundation's hook into our renderer: it asks this compositor for every frame it plays or
/// exports, so preview and export are drawn by the same Metal code. AVFoundation creates it
/// itself, so the shared GPU setup arrives with each frame's instruction.
final class MetalCompositor: NSObject, AVVideoCompositing {

  // MARK: Internal

  let sourcePixelBufferAttributes: [String: any Sendable]? = pixelBufferAttributes
  let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = pixelBufferAttributes

  func renderContextChanged(_: AVVideoCompositionRenderContext) { }

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    // why: AVFoundation's render threads may not drain autorelease pools between frames, so the
    // textures and command buffers each frame makes are released here, per frame.
    autoreleasepool { render(request) }
  }

  // MARK: Private

  /// Draws one frame of the composition.
  private func render(_ request: AVAsynchronousVideoCompositionRequest) {
    guard
      let instruction = request.videoCompositionInstruction as? CompositionInstruction,
      let output = request.renderContext.newPixelBuffer()
    else {
      logger.error("frame.renderFailed reason=missingInput")
      request.finish(with: EngineError.renderFailed)
      return
    }
    let width = CVPixelBufferGetWidth(output)
    let height = CVPixelBufferGetHeight(output)
    let layers = instruction.layers.compactMap { layer -> RenderLayer? in
      guard
        let style = instruction.renderState.style(of: layer.clipID), style.isVisible,
        style.opacity > 0
      else {
        return nil
      }
      let picture: LayerPicture?
      let rotation: CGAffineTransform
      switch layer.source {
      case .video(let trackID, let sourceRotation):
        picture = request.sourceFrame(byTrackID: trackID).map(LayerPicture.frame)
        rotation = sourceRotation

      case .text:
        let texture = style.text.flatMap { text in
          instruction.renderContext.caption(text, width: width, height: height)
        }
        picture = texture.map(LayerPicture.surface)
        rotation = .identity
      }
      return picture.map { picture in
        RenderLayer(
          source: picture,
          rotation: rotation,
          transform: style.transform,
          opacity: style.opacity,
        )
      }
    }
    do {
      try instruction.renderContext.renderer.draw(layers, into: output)
    } catch {
      request.finish(with: error)
      return
    }
    instruction.frameCounter.recordFrame()
    request.finish(withComposedVideoFrame: output)
  }

}

/// 8-bit BGRA, readable by Metal: the format every frame uses on its way through the compositor.
private let pixelBufferAttributes: [String: any Sendable] = [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferMetalCompatibilityKey as String: true,
]
