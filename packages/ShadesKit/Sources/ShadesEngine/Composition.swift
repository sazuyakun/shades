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
  /// `sources` (its proxy) when given there. Clips whose media has a cut-out in `mattes` get it
  /// as a matching track, for depth slots.
  @MainActor
  static func build(
    _ project: Project,
    library: MediaLibrary,
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
    sources: [Media.ID: URL] = [:],
    mattes: [Media.ID: URL] = [:],
  ) async throws(EngineError) -> Composition {
    let timeline = project.timeline
    guard timeline.duration > .zero else {
      logger.error("composition.failed reason=timelineEmpty")
      throw .timelineEmpty
    }
    let asset = AVMutableComposition()
    var videoLayers = [VideoLayer]()
    var audioTrackIDs = [Track.ID: CMPersistentTrackID]()
    for track in timeline.tracks where !track.clips.isEmpty && track.kind != .text {
      var videoTrack: AVMutableCompositionTrack?
      var audioTrack: AVMutableCompositionTrack?
      var matteTrack: AVMutableCompositionTrack?
      var placed = [PlacedClip]()
      for clip in track.clips {
        guard let mediaID = clip.mediaID else {
          if clip.drawing != nil {
            placed.append(PlacedClip(
              clip: clip,
              rotation: .identity,
              hasMatte: false,
              drawn: .drawing,
            ))
          }
          continue
        }
        let media = try project.mediaForPlayback(mediaID)
        guard !media.isStill else {
          placed.append(PlacedClip(
            clip: clip,
            rotation: .identity,
            hasMatte: false,
            drawn: .still(media.url),
          ))
          continue
        }
        let source = try await library.tracks(at: sources[media.id] ?? media.url)
        let range = CMTimeRange(start: clip.sourceStart.cmTime, duration: clip.duration.cmTime)
        do {
          if track.kind == .video, let video = source.video {
            let target = try videoTrack ?? addTrack(.video, to: asset)
            videoTrack = target
            try target.insertTimeRange(range, of: video, at: clip.timelineStart.cmTime)
            var hasMatte = false
            if
              let matteURL = mattes[media.id],
              let matte = try await library.tracks(at: matteURL).video
            {
              let target = try matteTrack ?? addTrack(.video, to: asset)
              matteTrack = target
              // why: a matte can end a frame early; only the part it covers is used.
              let available = try await matte.load(.timeRange).end
              let end = min(range.end, available)
              if end > range.start {
                try target.insertTimeRange(
                  CMTimeRange(start: range.start, end: end),
                  of: matte,
                  at: clip.timelineStart.cmTime,
                )
                hasMatte = true
              }
            }
            placed.append(PlacedClip(
              clip: clip,
              rotation: source.rotation,
              hasMatte: hasMatte,
              drawn: nil,
            ))
          }
          if let audio = source.audio {
            let target = try audioTrack ?? addTrack(.audio, to: asset)
            audioTrack = target
            audioTrackIDs[track.id] = target.trackID
            try target.insertTimeRange(range, of: audio, at: clip.timelineStart.cmTime)
          }
        } catch {
          let code = (error as NSError).code
          let path = media.url.path
          logger.error(
            "composition.failed reason=insert code=\(code) path=\(path, privacy: .private)"
          )
          throw .mediaUnreadable(media.url)
        }
      }
      if !placed.isEmpty {
        videoLayers.append(VideoLayer(
          trackID: videoTrack?.trackID,
          matteTrackID: matteTrack?.trackID,
          clips: placed,
        ))
      }
    }
    // why: AVFoundation only asks the compositor for frames while some video track plays, so a
    // timeline of only stills and text gets an empty one to carry it.
    if asset.tracks(withMediaType: .video).isEmpty {
      try addTrack(.video, to: asset).insertEmptyTimeRange(
        CMTimeRange(start: .zero, duration: timeline.duration.cmTime)
      )
    }
    let textLayers = timeline.tracks.filter { $0.kind == .text }.map(\.clips)
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
      text: textLayers,
      duration: timeline.duration,
      renderState: renderState,
      renderContext: renderContext,
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
    for layers: [VideoLayer],
    text: [[Clip]],
    duration: MediaTime,
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
  ) -> [CompositionInstruction] {
    var edges: Set = [MediaTime.zero, duration]
    for clip in layers.flatMap({ $0.clips.map(\.clip) }) + text.flatMap(\.self) {
      edges.insert(clip.timelineStart)
      edges.insert(clip.timelineEnd)
    }
    let sorted = edges.sorted()
    return zip(sorted, sorted.dropFirst()).map { start, end in
      let video = layers.compactMap { layer -> CompositionLayer? in
        guard let placed = layer.clips.first(where: { $0.clip.contains(start) }) else {
          return nil
        }
        guard
          let source = placed.drawn
          ?? layer.trackID.map({ LayerSource.video(trackID: $0, rotation: placed.rotation) })
        else {
          return nil
        }
        return CompositionLayer(
          clipID: placed.clip.id,
          source: source,
          matteTrackID: placed.hasMatte ? layer.matteTrackID : nil,
        )
      }
      let words = text.compactMap { clips in
        clips.first { $0.contains(start) }.map { CompositionLayer(
          clipID: $0.id,
          source: .text,
          matteTrackID: nil,
        ) }
      }
      let showing = video + words
      return CompositionInstruction(
        timeRange: CMTimeRange(start: start.cmTime, end: end.cmTime),
        layers: showing,
        renderState: renderState,
        renderContext: renderContext,
        frameCounter: frameCounter,
      )
    }
  }

}

// MARK: - VideoLayer

/// A timeline track's video in the composition (none when it holds only stills), and its
/// cut-outs' track if any.
private struct VideoLayer {
  let trackID: CMPersistentTrackID?
  let matteTrackID: CMPersistentTrackID?
  let clips: [PlacedClip]
}

// MARK: - PlacedClip

/// A clip placed in the composition: its rotation, whether its cut-out came with it, and how
/// it's drawn when it isn't video (a still or a drawing).
private struct PlacedClip {
  let clip: Clip
  let rotation: CGAffineTransform
  let hasMatte: Bool
  let drawn: LayerSource?
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
  let mediaID: Media.ID?
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
