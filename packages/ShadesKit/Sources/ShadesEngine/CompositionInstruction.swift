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
    let trackIDs = layers.compactMap { layer -> NSNumber? in
      if case .video(let trackID, _) = layer.source {
        return NSNumber(value: trackID)
      }
      return nil
    }
    return trackIDs.isEmpty ? nil : trackIDs
  }

}

// MARK: - CompositionLayer

/// One clip showing during an instruction, and where its picture comes from.
struct CompositionLayer: Sendable {
  let clipID: UUID
  let source: LayerSource
}

// MARK: - LayerSource

/// Where a layer's picture comes from.
enum LayerSource: Sendable {
  /// Video frames from a composition track, with the stored-to-upright rotation.
  case video(trackID: CMPersistentTrackID, rotation: CGAffineTransform)
  /// Text, drawn from the clip's words in `RenderState`.
  case text
}
