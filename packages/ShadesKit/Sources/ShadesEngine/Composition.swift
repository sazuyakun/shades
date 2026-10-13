import AVFoundation
import ShadesCore

// MARK: - Composition

/// A timeline turned into something AVFoundation can play and render.
public struct Composition {
  /// The clips' media laid out in timeline order.
  public let asset: AVComposition
  /// How each frame is drawn: by `MetalCompositor`.
  public let videoComposition: AVVideoComposition
}

extension Composition {

  // MARK: Internal

  /// Builds the playable form of the project's timeline.
  @MainActor
  static func build(
    _ project: Project,
    frameCounter: FrameCounter,
  ) async throws(EngineError) -> Composition {
    let clips = project.timeline.tracks.first?.clips ?? []
    guard let firstClip = clips.first else {
      logger.error("composition.failed reason=timelineEmpty")
      throw .timelineEmpty
    }
    let asset = AVMutableComposition()
    guard
      let videoTrack = asset.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid,
      ),
      let audioTrack = asset.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid,
      )
    else {
      logger.fault("composition.failed reason=addTrack")
      assertionFailure("AVMutableComposition refused to add a track")
      throw .compositionFailed
    }
    var transforms = [CGAffineTransform]()
    for clip in clips {
      try await transforms.append(insert(clip, of: project, into: videoTrack, audioTrack))
    }
    let videoComposition = AVMutableVideoComposition()
    videoComposition.customVideoCompositorClass = MetalCompositor.self
    videoComposition.renderSize = try renderSize(for: firstClip, in: project)
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = instructions(
      for: Array(zip(clips, transforms)),
      duration: project.timeline.duration,
      trackID: videoTrack.trackID,
      frameCounter: frameCounter,
    )
    return Composition(asset: asset, videoComposition: videoComposition)
  }

  // MARK: Private

  /// Inserts the clip's video and audio, and returns its video's rotation.
  @MainActor
  private static func insert(
    _ clip: Clip,
    of project: Project,
    into videoTrack: AVMutableCompositionTrack,
    _ audioTrack: AVMutableCompositionTrack,
  ) async throws(EngineError) -> CGAffineTransform {
    guard let media = project.media(withID: clip.mediaID) else {
      logger.error("composition.failed reason=mediaMissing id=\(clip.mediaID, privacy: .public)")
      throw .mediaMissing(clip.mediaID)
    }
    let source = AVURLAsset(url: media.url)
    let range = CMTimeRange(start: clip.sourceStart.cmTime, duration: clip.duration.cmTime)
    do {
      var transform = CGAffineTransform.identity
      if let sourceVideo = try await source.loadTracks(withMediaType: .video).first {
        try videoTrack.insertTimeRange(range, of: sourceVideo, at: clip.timelineStart.cmTime)
        transform = try await sourceVideo.load(.preferredTransform)
      }
      if let sourceAudio = try await source.loadTracks(withMediaType: .audio).first {
        try audioTrack.insertTimeRange(range, of: sourceAudio, at: clip.timelineStart.cmTime)
      }
      return transform
    } catch {
      logger
        .error(
          "composition.failed reason=mediaUnreadable path=\(media.url.path, privacy: .private)"
        )
      throw .mediaUnreadable(media.url)
    }
  }

  /// One instruction per clip (carrying its rotation) and one per gap, covering the whole
  /// timeline without overlaps, as AVFoundation requires.
  private static func instructions(
    for clips: [(Clip, CGAffineTransform)],
    duration: MediaTime,
    trackID: CMPersistentTrackID,
    frameCounter: FrameCounter,
  ) -> [CompositionInstruction] {
    var instructions = [CompositionInstruction]()
    var cursor = MediaTime.zero
    func add(from start: MediaTime, to end: MediaTime, transform: CGAffineTransform) {
      let range = CMTimeRange(start: start.cmTime, end: end.cmTime)
      instructions.append(
        CompositionInstruction(
          timeRange: range,
          trackID: trackID,
          transform: transform,
          frameCounter: frameCounter,
        )
      )
    }
    for (clip, transform) in clips.sorted(by: { $0.0.timelineStart < $1.0.timelineStart }) {
      if cursor < clip.timelineStart {
        add(from: cursor, to: clip.timelineStart, transform: .identity)
      }
      add(from: clip.timelineStart, to: clip.timelineEnd, transform: transform)
      cursor = clip.timelineEnd
    }
    if cursor < duration {
      add(from: cursor, to: duration, transform: .identity)
    }
    return instructions
  }

  /// M0 renders at the size of the first clip's media. Project formats arrive with presets.
  private static func renderSize(
    for clip: Clip,
    in project: Project,
  ) throws(EngineError) -> CGSize {
    guard let media = project.media(withID: clip.mediaID) else {
      logger.error("composition.failed reason=mediaMissing id=\(clip.mediaID, privacy: .public)")
      throw .mediaMissing(clip.mediaID)
    }
    return CGSize(width: media.width, height: media.height)
  }

}
