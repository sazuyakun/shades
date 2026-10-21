import AVFoundation
import ShadesCore

// MARK: - CompositionInstruction

/// Tells `MetalCompositor` what to draw over one stretch of the timeline: the clips showing
/// there, bottom to top (none in a gap, which draws black).
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {

  // MARK: Lifecycle

  init(
    timeRange: CMTimeRange,
    layers: [CompositionLayer],
    pictureSize: CGSize,
    isCanvas: Bool,
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
    quality: RenderQuality,
  ) {
    self.timeRange = timeRange
    self.layers = layers
    self.pictureSize = pictureSize
    self.isCanvas = isCanvas
    self.renderState = renderState
    self.renderContext = renderContext
    self.frameCounter = frameCounter
    self.quality = quality
  }

  // MARK: Internal

  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = true
  let passthroughTrackID = kCMPersistentTrackID_Invalid
  let layers: [CompositionLayer]
  /// The timeline's picture size.
  let pictureSize: CGSize
  /// Whether frames are a canvas with the picture drawn at `pictureSize` in the middle; when
  /// not, frames are the picture itself, at whatever size they're rendered (smaller to preview).
  let isCanvas: Bool
  let renderState: RenderState
  let renderContext: RenderContext
  let frameCounter: FrameCounter
  /// How finely motion blur is drawn: lighter for playback.
  let quality: RenderQuality

  var requiredSourceTrackIDs: [NSValue]? {
    let trackIDs = layers.flatMap { layer -> [NSNumber] in
      guard case .video(let trackID, _) = layer.source else {
        return []
      }
      return [trackID, layer.matteTrackID, layer.flowTrackID]
        .compactMap { $0.map { NSNumber(value: $0) } }
    }
    return trackIDs.isEmpty ? nil : trackIDs
  }

}

// MARK: - CompositionLayer

/// One clip showing during an instruction, and where its picture comes from.
struct CompositionLayer: Sendable {
  let clipID: UUID
  let source: LayerSource
  /// Where the clip's cut-out frames come from, when it has one.
  let matteTrackID: CMPersistentTrackID?
  /// Where its media's optical flow frames come from, when it has one (for footage blur).
  let flowTrackID: CMPersistentTrackID?
  /// The transition the clip is part of here, if any.
  let transition: TransitionPart?
}

// MARK: - TransitionPart

/// A clip's part in a transition: which kind, when it runs, and whether the clip is coming in.
struct TransitionPart: Sendable {
  let kind: TransitionKind
  let start: MediaTime
  let duration: MediaTime
  let isIncoming: Bool

  /// How far through the transition `time` is, 0 to 1.
  func progress(at time: MediaTime) -> Double {
    min(max((time - start).seconds / max(duration.seconds, 0.001), 0), 1)
  }

  /// How the transition shapes the clip at `time`.
  func style(at time: MediaTime) -> TransitionStyle {
    TransitionStyle(kind: kind, progress: progress(at: time), isIncoming: isIncoming)
  }
}

// MARK: - LayerSource

/// Where a layer's picture comes from.
enum LayerSource: Sendable {
  /// Video frames from a composition track, with the stored-to-upright rotation.
  case video(trackID: CMPersistentTrackID, rotation: CGAffineTransform)
  /// Text, drawn from the clip's words in `RenderState`.
  case text
  /// A still picture (PNG, photo), drawn from its file.
  case still(URL)
  /// Hand-drawn lines, from the clip's drawing in `RenderState`.
  case drawing
  /// An adjustment clip: the frame so far, graded and given its effects.
  case adjustment
}
