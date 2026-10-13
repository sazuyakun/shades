import AVFoundation

/// Tells `MetalCompositor` which source track to draw over a stretch of the timeline.
final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol {

  // MARK: Lifecycle

  init(timeRange: CMTimeRange, trackID: CMPersistentTrackID, frameCounter: FrameCounter) {
    self.timeRange = timeRange
    self.trackID = trackID
    self.frameCounter = frameCounter
  }

  // MARK: Internal

  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = true
  let passthroughTrackID = kCMPersistentTrackID_Invalid
  let trackID: CMPersistentTrackID
  let frameCounter: FrameCounter

  var requiredSourceTrackIDs: [NSValue]? {
    [NSNumber(value: trackID)]
  }

}
