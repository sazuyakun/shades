import AVFoundation
import ShadesCore

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
    let time = MediaTime(seconds: request.compositionTime.seconds)
    let layers = instruction.layers.compactMap { layer -> RenderLayer? in
      guard let style = instruction.renderState.style(of: layer.clipID), style.isVisible else {
        return nil
      }
      let opacity = style.clip.opacity(at: time)
      guard opacity > 0 else {
        return nil
      }
      let clip = style.clip
      var transform = clip.transform(at: time)
      let picture: LayerPicture?
      let rotation: CGAffineTransform
      var isText = false
      switch layer.source {
      case .video(let trackID, let sourceRotation):
        picture = request.sourceFrame(byTrackID: trackID).map(LayerPicture.frame)
        rotation = sourceRotation

      case .text:
        let drawn = clip.text.flatMap { content in
          instruction.renderContext.text(
            content,
            at: clip.sourceTime(at: time).seconds,
            duration: clip.duration.seconds,
            width: width,
            height: height,
          )
        }
        picture = drawn.map { LayerPicture.surface($0.surface) }
        transform.x += drawn.map { Double($0.offset.x) } ?? 0
        transform.y += drawn.map { Double($0.offset.y) } ?? 0
        rotation = .identity
        isText = true
      }
      let matte = layer.matteTrackID.flatMap { request.sourceFrame(byTrackID: $0) }
        .map(LayerPicture.frame)
      return picture.map { picture in
        RenderLayer(
          source: picture,
          rotation: rotation,
          transform: transform,
          opacity: opacity,
          depth: clip.depth,
          matte: matte,
          isNaturalSize: isText,
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
