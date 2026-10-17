import AVFoundation
import ShadesCore

// MARK: - Composition

/// A timeline turned into something AVFoundation can play and render: one composition track
/// per timeline track, drawn by `MetalCompositor`.
public struct Composition {
  /// The clips' media laid out in time.
  public let asset: AVComposition
  /// How each frame is drawn: by `MetalCompositor`, layer by layer.
  public let videoComposition: AVVideoComposition

  /// Which composition track carries each timeline track's sound, for the audio mix.
  let audioTrackIDs: [Track.ID: CMPersistentTrackID]
}

extension Composition {

  // MARK: Internal

  /// What, if it changes, means playback must be rebuilt: the frame format and every clip's
  /// timing and media. A clip's look and volume aren't part of it; they change live.
  struct Structure: Hashable {
    init(_ timeline: Timeline) {
      format = timeline.format
      tracks = timeline.tracks.map { track in
        TrackStructure(id: track.id, kind: track.kind, clips: track.clips.map(ClipTiming.init))
      }
    }

    let format: VideoFormat
    let tracks: [TrackStructure]
  }

  /// Builds the playable form of the project's timeline, reading each media file from
  /// `sources` (its proxy) when given there.
  @MainActor
  static func build(
    _ project: Project,
    library: MediaLibrary,
    renderState: RenderState,
    frameCounter: FrameCounter,
    sources: [Media.ID: URL] = [:],
  ) async throws(EngineError) -> Composition {
    let timeline = project.timeline
    guard timeline.duration > .zero else {
      logger.error("composition.failed reason=timelineEmpty")
      throw .timelineEmpty
    }
    let asset = AVMutableComposition()
    var videoLayers = [(trackID: CMPersistentTrackID, clips: [(Clip, CGAffineTransform)])]()
    var audioTrackIDs = [Track.ID: CMPersistentTrackID]()
    for track in timeline.tracks where !track.clips.isEmpty {
      let videoTrack = track.kind == .video ? try addTrack(.video, to: asset) : nil
      var audioTrack: AVMutableCompositionTrack?
      var placed = [(Clip, CGAffineTransform)]()
      for clip in track.clips {
        let media = try project.mediaForPlayback(clip.mediaID)
        let source = try await library.tracks(at: sources[media.id] ?? media.url)
        let range = CMTimeRange(start: clip.sourceStart.cmTime, duration: clip.duration.cmTime)
        do {
          if let videoTrack, let video = source.video {
            try videoTrack.insertTimeRange(range, of: video, at: clip.timelineStart.cmTime)
            placed.append((clip, source.rotation))
          }
          if let audio = source.audio {
            let target = try audioTrack ?? addTrack(.audio, to: asset)
            audioTrack = target
            audioTrackIDs[track.id] = target.trackID
            try target.insertTimeRange(range, of: audio, at: clip.timelineStart.cmTime)
          }
        } catch {
          logger.error("composition.failed reason=insert path=\(media.url.path, privacy: .private)")
          throw .mediaUnreadable(media.url)
        }
      }
      if let videoTrack {
        videoLayers.append((videoTrack.trackID, placed))
      }
    }
    let videoComposition = AVMutableVideoComposition()
    videoComposition.customVideoCompositorClass = MetalCompositor.self
    videoComposition.renderSize = CGSize(
      width: timeline.format.width,
      height: timeline.format.height,
    )
    videoComposition.frameDuration = CMTime(
      value: 1,
      timescale: CMTimeScale(timeline.format.framesPerSecond),
    )
    videoComposition.instructions = instructions(
      for: videoLayers,
      duration: timeline.duration,
      renderState: renderState,
      frameCounter: frameCounter,
    )
    return Composition(
      asset: asset,
      videoComposition: videoComposition,
      audioTrackIDs: audioTrackIDs,
    )
  }

  /// Each track's volume over time: a clip's own volume, or silence where the track is muted or
  /// a video clip's sound was detached.
  func audioMix(for timeline: Timeline) -> AVAudioMix {
    let mix = AVMutableAudioMix()
    mix.inputParameters = timeline.tracks.compactMap { track in
      guard let trackID = audioTrackIDs[track.id] else {
        return nil
      }
      let parameters = AVMutableAudioMixInputParameters()
      parameters.trackID = trackID
      for clip in track.clips {
        let isAudible = !track.isMuted && (track.kind == .audio || clip.isAudioEnabled)
        parameters.setVolume(Float(isAudible ? clip.volume : 0), at: clip.timelineStart.cmTime)
      }
      return parameters
    }
    return mix
  }

  // MARK: Private

  private static func addTrack(
    _ type: AVMediaType,
    to asset: AVMutableComposition,
  ) throws(EngineError) -> AVMutableCompositionTrack {
    guard
      let track = asset.addMutableTrack(
        withMediaType: type,
        preferredTrackID: kCMPersistentTrackID_Invalid,
      )
    else {
      logger.fault("composition.failed reason=addTrack")
      assertionFailure("AVMutableComposition refused to add a track")
      throw .compositionFailed
    }
    return track
  }

  /// One instruction for every stretch between clip edges, listing the clips showing there
  /// bottom to top, covering the whole timeline without overlaps as AVFoundation requires.
  private static func instructions(
    for layers: [(trackID: CMPersistentTrackID, clips: [(Clip, CGAffineTransform)])],
    duration: MediaTime,
    renderState: RenderState,
    frameCounter: FrameCounter,
  ) -> [CompositionInstruction] {
    var edges: Set = [MediaTime.zero, duration]
    for layer in layers {
      for (clip, _) in layer.clips {
        edges.insert(clip.timelineStart)
        edges.insert(clip.timelineEnd)
      }
    }
    let sorted = edges.sorted()
    return zip(sorted, sorted.dropFirst()).map { start, end in
      let showing = layers.compactMap { layer -> CompositionLayer? in
        guard let (clip, rotation) = layer.clips.first(where: { $0.0.contains(start) }) else {
          return nil
        }
        return CompositionLayer(trackID: layer.trackID, clipID: clip.id, rotation: rotation)
      }
      return CompositionInstruction(
        timeRange: CMTimeRange(start: start.cmTime, end: end.cmTime),
        layers: showing,
        renderState: renderState,
        frameCounter: frameCounter,
      )
    }
  }

}

// MARK: - TrackStructure

/// A track's part of `Composition.Structure`.
struct TrackStructure: Hashable {
  let id: Track.ID
  let kind: TrackKind
  let clips: [ClipTiming]
}

// MARK: - ClipTiming

/// A clip's timing and media: the part of it that shapes the composition.
struct ClipTiming: Hashable {
  init(_ clip: Clip) {
    id = clip.id
    mediaID = clip.mediaID
    sourceStart = clip.sourceStart
    duration = clip.duration
    timelineStart = clip.timelineStart
  }

  let id: Clip.ID
  let mediaID: Media.ID
  let sourceStart: MediaTime
  let duration: MediaTime
  let timelineStart: MediaTime
}

extension Project {
  /// The media a clip plays, or an error naming it.
  fileprivate func mediaForPlayback(_ id: Media.ID) throws(EngineError) -> Media {
    guard let media = media(withID: id) else {
      logger.error("composition.failed reason=mediaMissing id=\(id, privacy: .public)")
      throw .mediaMissing(id)
    }
    return media
  }
}
