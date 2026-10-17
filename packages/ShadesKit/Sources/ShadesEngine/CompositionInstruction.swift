import AVFoundation

// MARK: - CompositionInstruction

/// Tells `MetalCompositor` what to draw over one stretch of the timeline: the clips showing
/// there, bottom to top (none in a gap, which draws black).
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {

  // MARK: Lifecycle

  init(
    timeRange: CMTimeRange,
    layers: [CompositionLayer],
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
  ) {
    self.timeRange = timeRange
    self.layers = layers
    self.renderState = renderState
    self.renderContext = renderContext
    self.frameCounter = frameCounter
  }

  // MARK: Internal

  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = true
  let passthroughTrackID = kCMPersistentTrackID_Invalid
  let layers: [CompositionLayer]
  let renderState: RenderState
  let renderContext: RenderContext
  let frameCounter: FrameCounter

  var requiredSourceTrackIDs: [NSValue]? {
    layers.isEmpty ? nil : layers.map { NSNumber(value: $0.trackID) }
  }

}

// MARK: - CompositionLayer

/// One clip showing during an instruction: where its frames come from and how they're rotated.
struct CompositionLayer: Sendable {
  let trackID: CMPersistentTrackID
  let clipID: UUID
  /// The source video's stored-to-upright rotation (its `preferredTransform`).
  let rotation: CGAffineTransform
}
