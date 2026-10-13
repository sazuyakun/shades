import AVFoundation

/// Tells `MetalCompositor` what to draw over one stretch of the timeline: which source track,
/// and the rotation of the clip there (identity in a gap).
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {

  // MARK: Lifecycle

  init(
    timeRange: CMTimeRange,
    trackID: CMPersistentTrackID,
    transform: CGAffineTransform,
    frameCounter: FrameCounter,
  ) {
    self.timeRange = timeRange
    self.trackID = trackID
    self.transform = transform
    self.frameCounter = frameCounter
  }

  // MARK: Internal

  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = true
  let passthroughTrackID = kCMPersistentTrackID_Invalid
  let trackID: CMPersistentTrackID
  /// The clip's stored-to-upright rotation (its source track's `preferredTransform`).
  let transform: CGAffineTransform
  let frameCounter: FrameCounter

  var requiredSourceTrackIDs: [NSValue]? {
    [NSNumber(value: trackID)]
  }

}
