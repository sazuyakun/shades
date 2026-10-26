import AVFoundation
import ShadesCore

// MARK: - MetalCompositor

/// AVFoundation's hook into our renderer: it asks this compositor for every frame it plays or
/// exports, so preview and export are drawn by the same Metal code. AVFoundation creates it
/// itself, so the shared GPU setup arrives with each frame's instruction.
final class MetalCompositor: NSObject, AVVideoCompositing {

  // MARK: Internal

  /// HDR and wide-colour frames come in as they are; the layer shader tone-maps HDR itself
  /// (see `SourceColor`), as AVFoundation's own conversion leaves HLG footage dim.
  let supportsHDRSourceFrames = true
  let supportsWideColorSourceFrames = true
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
    let started = ContinuousClock.now
    guard
      let instruction = request.videoCompositionInstruction as? CompositionInstruction,
      let output = request.renderContext.newPixelBuffer()
    else {
      logger.error("frame.renderFailed reason=missingInput")
      request.finish(with: EngineError.renderFailed)
      return
    }
    let isCanvas = instruction.isCanvas
    let width = isCanvas ? Int(instruction.pictureSize.width) : CVPixelBufferGetWidth(output)
    let height = isCanvas ? Int(instruction.pictureSize.height) : CVPixelBufferGetHeight(output)
    let drawSize = CGSize(width: width, height: height)
    // why: a preview drawn smaller than the timeline keeps blurs and glows the same size in the
    // picture, so it looks like the export, just softer.
    let scale = Double(width) / max(instruction.pictureSize.width, 1)
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
      let source = clip.sourceTime(at: time)
      var offset = CGPoint.zero
      let picture: LayerPicture?
      let rotation: CGAffineTransform
      var isText = false
      var solid: SolidText?
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
            at: source.seconds,
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
        let drawn = instruction.renderContext.text(of: clip, at: time, width: width, height: height)
        picture = drawn.map { LayerPicture.surface($0.surface) }
        offset = drawn?.offset ?? .zero
        solid = drawn?.solid
        rotation = .identity
        isText = true
      }
      let isAdjustment = clip.source == .adjustment
      let follows = style.followsCamera && !isAdjustment
      let travelsPath = isText && clip.keyframes.contains { $0.property == .pathOffset }
      let pathLength = travelsPath ? clip.text?.path.map { span(of: $0, in: drawSize) } ?? 0 : 0.0
      let zooms = clip.effects?.portal != nil && clip.keyframes.contains { $0.property == .portal }
      let place = { (moment: MediaTime) -> LayerPose in
        // why: an adjustment works on the whole frame, wherever the clip or camera would move it.
        guard !isAdjustment else {
          return LayerPose(transform: .identity, camera: .identity)
        }
        var moved: DrawnText?
        var drift = 0.0
        if travelsPath {
          let along = clip.value(of: .pathOffset, at: moment)
          drift = along * pathLength
          // why: the text's own picture changes as it travels, so each moment draws its own.
          if along != clip.value(of: .pathOffset, at: time) {
            moved = instruction.renderContext.text(
              of: clip,
              at: moment,
              width: width,
              height: height,
            )
          }
        }
        var travel: Double?
        if zooms, let nesting = clip.effects?.portal?.nesting {
          let zoom = clip.value(of: .portal, at: moment)
          travel = zoom
          // why: a zoom of one copy moves the picture's edge by about its half-diagonal times
          // the log of the nesting.
          drift += zoom * log(nesting) * Double(hypot(drawSize.width, drawSize.height)) / 2
        }
        var transform = clip.transform(at: moment)
        let transition = layer.transition?.style(at: moment)
        let shift = moved?.offset ?? offset
        transform.x += Double(shift.x) + (transition?.offsetX ?? 0)
        transform.scale *= transition?.scale ?? 1
        transform.y += Double(shift.y)
        return LayerPose(
          transform: transform,
          camera: follows ? instruction.renderState.camera(at: moment) : .identity,
          drift: drift,
          picture: moved.map { LayerPicture.surface($0.surface) },
          portalTravel: travel,
        )
      }
      let pose = place(time)
      let matte = layer.matteTrackID.flatMap { request.sourceFrame(byTrackID: $0) }
        .map(LayerPicture.frame)
      let length = shutter * clip.motionBlur
      let footage = layer.flowTrackID.flatMap { trackID -> FootageBlur? in
        guard clip.footageBlur, length > 0, let flow = request.sourceFrame(byTrackID: trackID)
        else {
          return nil
        }
        let half = MediaTime(seconds: length / 2, timescale: Shutter.timescale)
        return FootageBlur(
          flow: flow,
          length: (clip.sourceTime(at: time + half) - clip.sourceTime(at: time - half)).seconds,
          taps: instruction.quality.footageTaps,
        )
      }
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
          grade: clip.grade.map { grade in
            var placed = grade
            placed.window = grade.window?.placed(at: source)
            return placed
          },
          effects: effects(of: clip, at: time, in: transition),
          crop: clip.crop,
          masks: clip.masks.map { $0.placed(at: source) },
          cutoutEdge: clip.cutoutEdge,
          blend: clip.blend,
          transition: transition,
          clipTime: source.seconds,
          shutter: isAdjustment
            ? []
            : Shutter.poses(
              around: time,
              length: length,
              size: drawSize,
              limit: instruction.quality.layerSamples,
              place: place,
            ),
          footageBlur: footage,
          solid: solid,
        )
      }
    }
    do {
      if isCanvas {
        let picture = try RenderContext.pictureBuffer(width: width, height: height)
        try instruction.renderContext.renderer.draw(layers, into: picture, seed: time.seconds)
        instruction.renderContext.place(picture, onCanvas: output)
      } else {
        try instruction.renderContext.renderer.draw(
          layers,
          into: output,
          seed: time.seconds,
          scale: scale,
        )
      }
    } catch {
      request.finish(with: error)
      return
    }
    // why: AVFoundation copies a source's tags onto the frame, but every frame leaves here in
    // the Rec.709 working space; the viewer and the encoder read these tags.
    for (key, value) in [
      (kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2),
      (kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2),
      (kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2),
    ] {
      CVBufferSetAttachment(output, key, value, .shouldPropagate)
    }
    instruction.frameCounter.recordFrame(at: time.seconds, took: .now - started)
    request.finish(withComposedVideoFrame: output)
  }

  /// How long `path` is, in pixels of a `size` frame.
  private func span(of path: TextPath, in size: CGSize) -> Double {
    zip(path.points, path.points.dropFirst()).reduce(0.0) { total, step in
      total + hypot(
        (step.1.x - step.0.x) * Double(size.width),
        (step.1.y - step.0.y) * Double(size.height),
      )
    }
  }

  /// The clip's effects at `time`: its endless zoom travelled as far as its keyframes say, and
  /// blurred by a transition that smears it.
  private func effects(
    of clip: Clip,
    at time: MediaTime,
    in transition: TransitionStyle?,
  ) -> Effects? {
    guard transition != nil || clip.effects?.portal != nil else {
      return clip.effects
    }
    var effects = clip.effects ?? Effects()
    effects.blur = max(effects.blur, transition?.blur ?? 0)
    effects.portal?.travel = clip.value(of: .portal, at: time)
    return effects
  }

}

/// 8-bit BGRA, readable by Metal: the format every frame uses on its way through the compositor.
private let pixelBufferAttributes: [String: any Sendable] = [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferMetalCompatibilityKey as String: true,
]
