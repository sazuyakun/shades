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
    let width = Int(instruction.pictureSize.width)
    let height = Int(instruction.pictureSize.height)
    let isCanvas = CVPixelBufferGetWidth(output) != width || CVPixelBufferGetHeight(output) !=
      height
    let time = MediaTime(seconds: request.compositionTime.seconds)
    let shutter = instruction.renderState.shutter()
    let layers = instruction.layers.compactMap { layer -> RenderLayer? in
      guard let style = instruction.renderState.style(of: layer.clipID), style.isVisible else {
        return nil
      }
      let transition = layer.transition?.style(at: time)
      let opacity = style.clip.opacity(at: time) * (transition?.opacity ?? 1)
      guard opacity > 0 else {
        return nil
      }
      let clip = style.clip
      var offset = CGPoint.zero
      let picture: LayerPicture?
      let rotation: CGAffineTransform
      var isText = false
      switch layer.source {
      case .video(let trackID, let sourceRotation):
        picture = request.sourceFrame(byTrackID: trackID).map(LayerPicture.frame)
        rotation = sourceRotation

      case .still(let url):
        picture = instruction.renderContext.still(
          url,
          look: clip.sticker,
          width: width,
          height: height,
        ).map(LayerPicture.surface)
        rotation = .identity

      case .drawing:
        picture = clip.drawing.flatMap { drawing in
          instruction.renderContext.drawing(
            drawing,
            at: clip.sourceTime(at: time).seconds,
            duration: clip.duration.seconds,
            width: width,
            height: height,
          )
        }.map(LayerPicture.surface)
        rotation = .identity

      case .adjustment:
        picture = .backdrop
        rotation = .identity

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
        offset = drawn?.offset ?? .zero
        rotation = .identity
        isText = true
      }
      let isAdjustment = clip.source == .adjustment
      let follows = style.followsCamera && !isAdjustment
      let place = { (moment: MediaTime) -> LayerPose in
        // why: an adjustment works on the whole frame, wherever the clip or camera would move it.
        guard !isAdjustment else {
          return LayerPose(transform: .identity, camera: .identity)
        }
        var transform = clip.transform(at: moment)
        transform.x += Double(offset.x) + (layer.transition?.style(at: moment).offsetX ?? 0)
        transform.y += Double(offset.y)
        return LayerPose(
          transform: transform,
          camera: follows ? instruction.renderState.camera(at: moment) : .identity,
        )
      }
      let pose = place(time)
      let matte = layer.matteTrackID.flatMap { request.sourceFrame(byTrackID: $0) }
        .map(LayerPicture.frame)
      return picture.map { picture in
        RenderLayer(
          source: picture,
          rotation: rotation,
          transform: pose.transform,
          camera: pose.camera,
          opacity: opacity,
          depth: clip.depth,
          matte: matte,
          isNaturalSize: isText,
          grade: clip.grade,
          effects: transition.map { style in
            var effects = clip.effects ?? Effects()
            effects.blur = max(effects.blur, style.blur)
            return effects
          } ?? clip.effects,
          crop: clip.crop,
          blend: clip.blend,
          transition: transition,
          clipTime: clip.sourceTime(at: time).seconds,
          shutter: isAdjustment
            ? []
            : Shutter.poses(
              around: time,
              length: shutter * clip.motionBlur,
              size: instruction.pictureSize,
              limit: instruction.quality.layerSamples,
              place: place,
            ),
        )
      }
    }
    do {
      if isCanvas {
        let picture = try RenderContext.pictureBuffer(width: width, height: height)
        try instruction.renderContext.renderer.draw(layers, into: picture, seed: time.seconds)
        instruction.renderContext.place(picture, onCanvas: output)
      } else {
        try instruction.renderContext.renderer.draw(layers, into: output, seed: time.seconds)
      }
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
