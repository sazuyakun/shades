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

  // MARK: Public

  /// How sound played faster or slower is stretched: keeping its pitch.
  public static let timePitchAlgorithm = AVAudioTimePitchAlgorithm.spectral

  /// Builds the project's timeline from its original media, for rendering frames or a file:
  /// with cut-outs from `mattes`, optical flow from `flows` (footage blur), noise-reduced sound
  /// from `cleanSound` and stereo copies of mono sound from `stereoSound`, drawn in the middle
  /// of a black `canvas` when one is given. Pass a long-lived `context` when rendering often; a
  /// new one compiles the shaders again.
  @MainActor
  public static func forRendering(
    _ project: Project,
    context: RenderContext? = nil,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
    cleanSound: [Media.ID: URL] = [:],
    stereoSound: [Media.ID: URL] = [:],
    canvas: CGSize? = nil,
  ) async throws(EngineError) -> Composition {
    let renderState = RenderState()
    renderState.update(from: project.timeline)
    let renderContext =
      if let context {
        context
      } else {
        try RenderContext()
      }
    return try await build(
      project,
      library: MediaLibrary(),
      renderState: renderState,
      renderContext: renderContext,
      frameCounter: FrameCounter(),
      quality: .full,
      mattes: mattes,
      flows: flows,
      cleanSound: cleanSound,
      stereoSound: stereoSound,
      canvas: canvas,
    )
  }

  /// Each track's volume over time (a clip's own volume, or silence where the track is muted,
  /// another is soloed, or a video clip's sound was detached), its pan, and the master limiter,
  /// reporting each track's level to `meters` when given.
  public func audioMix(for timeline: Timeline, meters: MixMeters? = nil) -> AVAudioMix {
    Self.audioMix(for: timeline, trackIDs: audioTrackIDs, meters: meters)
  }

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
  /// as a matching track, for depth slots, likewise their optical flow in `flows` (footage blur),
  /// clips set to clean sound play `cleanSound`, and other clips of mono media play its stereo
  /// copy in `stereoSound` (so their track can pan them). With
  /// a `canvas`, frames are that size, with the picture in the middle on black. `quality` sets
  /// how finely motion blur is drawn.
  @MainActor
  static func build(
    _ project: Project,
    library: MediaLibrary,
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
    quality: RenderQuality,
    sources: [Media.ID: URL] = [:],
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
    cleanSound: [Media.ID: URL] = [:],
    stereoSound: [Media.ID: URL] = [:],
    canvas: CGSize? = nil,
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
      var flowTrack: AVMutableCompositionTrack?
      var placed = [PlacedClip]()
      for clip in track.clips {
        guard let mediaID = clip.mediaID else {
          let drawn: LayerSource? =
            switch clip.source {
            case .drawing: .drawing
            case .adjustment: .adjustment
            case .media,
                 .text: nil
            }
          if let drawn {
            placed.append(PlacedClip(
              clip: clip,
              rotation: .identity,
              hasMatte: false,
              drawn: drawn,
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
        let pieces = MediaPiece.pieces(of: clip, frame: timeline.format.frameDuration)
        do {
          if track.kind == .video, let video = source.video {
            let target = try videoTrack ?? addTrack(.video, to: asset)
            videoTrack = target
            for piece in pieces {
              try piece.insert(from: video, into: target)
            }
            var hasMatte = false
            if let url = mattes[media.id] {
              hasMatte = try await insertAnalysis(
                url,
                pieces: pieces,
                into: &matteTrack,
                of: asset,
                library: library,
              )
            }
            var hasFlow = false
            if let url = flows[media.id] {
              hasFlow = try await insertAnalysis(
                url,
                pieces: pieces,
                into: &flowTrack,
                of: asset,
                library: library,
              )
            }
            placed.append(PlacedClip(
              clip: clip,
              rotation: source.rotation,
              hasMatte: hasMatte,
              hasFlow: hasFlow,
              drawn: nil,
            ))
          }
          var sound = source.audio
          if let copy = Self.sound(of: clip, cleanSound: cleanSound, stereoSound: stereoSound) {
            sound = try await library.tracks(at: copy).audio
          }
          if let audio = sound, !clip.isFrozen {
            let target = try audioTrack ?? addTrack(.audio, to: asset)
            audioTrack = target
            audioTrackIDs[track.id] = target.trackID
            for piece in pieces {
              try piece.insert(from: audio, into: target)
            }
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
        let handleTrackID = try await addHandles(
          for: track,
          project: project,
          library: library,
          sources: sources,
          to: asset,
        )
        videoLayers.append(VideoLayer(
          trackID: videoTrack?.trackID,
          matteTrackID: matteTrack?.trackID,
          flowTrackID: flowTrack?.trackID,
          handleTrackID: handleTrackID,
          clips: placed,
          transitions: track.transitions,
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
    // why: no colour properties, so AVFoundation hands frames over as they are, with their own
    // tags; asked for Rec.709 it converts or only relabels them depending on the Mac. The layer
    // shader converts, `MetalCompositor` tags every frame Rec.709, and `MovieExporter` adds the
    // properties that tag its file.
    let pictureSize = CGSize(width: timeline.format.width, height: timeline.format.height)
    videoComposition.renderSize = canvas ?? pictureSize
    videoComposition.frameDuration = CMTime(
      value: 1,
      timescale: CMTimeScale(timeline.format.framesPerSecond),
    )
    videoComposition.instructions = instructions(
      for: videoLayers,
      text: textLayers,
      duration: timeline.duration,
      pictureSize: pictureSize,
      isCanvas: canvas != nil,
      renderState: renderState,
      renderContext: renderContext,
      frameCounter: frameCounter,
      quality: quality,
    )
    return Composition(
      asset: asset,
      videoComposition: videoComposition,
      audioTrackIDs: audioTrackIDs,
    )
  }

  /// The mix of `timeline` for the composition tracks carrying each timeline track's sound: clip
  /// volumes, fades and keyframes, track levels and the master level, as volume ramps; the
  /// master limiter and the track's pan in its tap (volume ramps are smoothed, too slow for a
  /// limiter), which also reports to `meters`.
  static func audioMix(
    for timeline: Timeline,
    trackIDs: [Track.ID: CMPersistentTrackID],
    meters: MixMeters? = nil,
  ) -> AVAudioMix {
    let mix = AVMutableAudioMix()
    mix.inputParameters = timeline.tracks.compactMap { track in
      guard let trackID = trackIDs[track.id] else {
        return nil
      }
      let parameters = AVMutableAudioMixInputParameters()
      parameters.trackID = trackID
      if !timeline.limiter.isEmpty || track.pan != 0 || meters != nil {
        parameters.audioTapProcessor = TrackTap(
          track: track.id,
          limiter: timeline.limiter,
          pan: track.pan,
          meters: meters,
        ).makeTap()
      }
      for clip in track.clips {
        let level = timeline.plays(clip, on: track) ? track.volume * timeline.gain : 0
        let moments = volumeMoments(of: clip)
        for (from, to) in zip(moments, moments.dropFirst()) {
          parameters.setVolumeRamp(
            fromStartVolume: Float(clip.gain(at: from) * level),
            toEndVolume: Float(clip.gain(at: to) * level),
            timeRange: CMTimeRange(start: from.cmTime, end: to.cmTime),
          )
        }
      }
      return parameters
    }
    return mix
  }

  /// The file a clip's sound plays from instead of its media, if any: its noise-reduced sound
  /// when it's set to clean sound and that's been made, else its media's stereo copy.
  static func sound(
    of clip: Clip,
    cleanSound: [Media.ID: URL],
    stereoSound: [Media.ID: URL],
  ) -> URL? {
    guard let mediaID = clip.mediaID else {
      return nil
    }
    return clip.cleanSound ? cleanSound[mediaID] ?? stereoSound[mediaID] : stereoSound[mediaID]
  }

  static func addTrack(
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

  // MARK: Private

  /// The moments a clip's volume ramps between: its ends, its fades' ends, and its volume and
  /// speed keyframes (speed mutes sound when extreme), with curves split into short straight
  /// steps.
  private static func volumeMoments(of clip: Clip) -> [MediaTime] {
    var moments: Set = [clip.timelineStart, clip.timelineEnd]
    moments.insert(min(clip.timelineStart + clip.fadeIn, clip.timelineEnd))
    moments.insert(max(clip.timelineEnd - clip.fadeOut, clip.timelineStart))
    let pairs = [AnimatedProperty.volume, .speed].flatMap { property in
      let keyframes = clip.keyframes.filter { $0.property == property }.sorted { $0.time < $1.time }
      return Array(zip(keyframes, keyframes.dropFirst()))
    }
    for (from, to) in pairs {
      let start = clip.timelineTime(atSource: from.time)
      let end = clip.timelineTime(atSource: to.time)
      // why: eight straight steps follow a curve closely enough to be inaudible; a linear
      // volume move is only straight on the timeline when the speed is steady.
      let isStraight = from.property == .volume && from.easing == .linear && !clip.hasSpeedRamp
      let steps = isStraight ? 1 : 8
      for step in 0 ... steps {
        moments
          .insert(start + MediaTime(seconds: (end - start).seconds * Double(step) / Double(steps)))
      }
    }
    return moments.filter { clip.timelineStart <= $0 && $0 <= clip.timelineEnd }.sorted()
  }

  /// Puts the parts of an analysis video (a cut-out or optical flow) matching a clip's `pieces`
  /// of its media into `track`, adding the track the first time. Returns whether any of it was
  /// there to use.
  @MainActor
  private static func insertAnalysis(
    _ url: URL,
    pieces: [MediaPiece],
    into track: inout AVMutableCompositionTrack?,
    of asset: AVMutableComposition,
    library: MediaLibrary,
  ) async throws -> Bool {
    guard let video = try await library.tracks(at: url).video else {
      return false
    }
    let target = try track ?? addTrack(.video, to: asset)
    track = target
    // why: an analysis video can end a frame early; only the part it covers is used.
    let available = try await video.load(.timeRange).end
    let covered = pieces.compactMap { $0.ending(by: available) }
    for piece in covered {
      try piece.insert(from: video, into: target)
    }
    return !covered.isEmpty
  }

  /// Adds a track holding the frames transitions on `track` show past their clips' edges: the
  /// incoming clip from before its start, the outgoing one after its end. Where the media runs
  /// out, its edge frame holds. Returns the track, or `nil` when no transition needs one.
  @MainActor
  private static func addHandles(
    for track: Track,
    project: Project,
    library: MediaLibrary,
    sources: [Media.ID: URL],
    to asset: AVMutableComposition,
  ) async throws(EngineError) -> CMPersistentTrackID? {
    var handles: AVMutableCompositionTrack?
    for (outgoing, incoming, transition) in track.transitions where track.kind == .video {
      let half = MediaTime(seconds: transition.duration.seconds / 2)
      let cut = incoming.timelineStart
      // why: past its edges a clip keeps its speed (its last speed, or held still if frozen).
      let pieces = [
        (incoming, incoming.sourceTime(at: cut - half), incoming.sourceStart, cut - half),
        (outgoing, outgoing.sourceEnd, outgoing.sourceTime(at: cut + half), cut),
      ]
      for (clip, from, to, at) in pieces {
        guard
          let mediaID = clip.mediaID,
          let media = project.media(withID: mediaID), !media.isStill,
          let video = try await library.tracks(at: sources[mediaID] ?? media.url).video
        else {
          continue
        }
        let target: AVMutableCompositionTrack
        if let handles {
          target = handles
        } else {
          target = try addTrack(.video, to: asset)
          handles = target
        }
        do {
          let end = try await video.load(.timeRange).end
          try insertHolding(
            video,
            from: from.cmTime,
            to: to.cmTime,
            over: half.cmTime,
            end: end,
            into: target,
            at: at.cmTime,
          )
        } catch {
          logger.error("composition.failed reason=handle path=\(media.url.path, privacy: .private)")
          throw .mediaUnreadable(media.url)
        }
      }
    }
    return handles?.trackID
  }

  /// Puts `video` from `from` to `to` into `target` at `at`, played over `length`, holding its
  /// first or last frame for whatever falls before its start or after `end`. When `from` and
  /// `to` are the same (a freeze frame), that frame holds for all of `length`.
  private static func insertHolding(
    _ video: AVAssetTrack,
    from: CMTime,
    to: CMTime,
    over length: CMTime,
    end: CMTime,
    into target: AVMutableCompositionTrack,
    at: CMTime,
  ) throws {
    let frame = CMTime(value: 1, timescale: 30)
    guard to > from else {
      let still = min(max(from, .zero), max(end - frame, .zero))
      try hold(video, frameAt: still, frame: frame, for: length, into: target, at: at)
      return
    }
    let isSteady = to - from == length
    // why: at a steady speed the lengths stay exact; otherwise they scale with the speed.
    let played = { (source: CMTime) in
      isSteady
        ? source
        : CMTime(
          seconds: source.seconds * length.seconds / (to - from).seconds,
          preferredTimescale: 60000,
        )
    }
    let start = max(from, .zero)
    let stop = min(to, end)
    var position = at
    if from < .zero {
      let held = played(.zero - from)
      try hold(video, frameAt: .zero, frame: frame, for: held, into: target, at: position)
      position = position + held
    }
    if stop > start {
      let piece = MediaPiece(
        source: CMTimeRange(start: start, end: stop),
        at: position,
        duration: played(stop - start),
      )
      try piece.insert(from: video, into: target)
      position = position + piece.duration
    }
    if to > end {
      try hold(
        video,
        frameAt: max(end - frame, .zero),
        frame: frame,
        for: played(to - max(end, from)),
        into: target,
        at: position,
      )
    }
  }

  /// One frame of `video` stretched to last `length`.
  private static func hold(
    _ video: AVAssetTrack,
    frameAt time: CMTime,
    frame: CMTime,
    for length: CMTime,
    into target: AVMutableCompositionTrack,
    at position: CMTime,
  ) throws {
    try target.insertTimeRange(CMTimeRange(start: time, duration: frame), of: video, at: position)
    target.scaleTimeRange(CMTimeRange(start: position, duration: frame), toDuration: length)
  }

  /// One instruction for every stretch between clip edges, listing the clips showing there
  /// bottom to top, covering the whole timeline without overlaps as AVFoundation requires.
  private static func instructions(
    for layers: [VideoLayer],
    text: [[Clip]],
    duration: MediaTime,
    pictureSize: CGSize,
    isCanvas: Bool,
    renderState: RenderState,
    renderContext: RenderContext,
    frameCounter: FrameCounter,
    quality: RenderQuality,
  ) -> [CompositionInstruction] {
    var edges: Set = [MediaTime.zero, duration]
    for clip in layers.flatMap({ $0.clips.map(\.clip) }) + text.flatMap(\.self) {
      edges.insert(clip.timelineStart)
      edges.insert(clip.timelineEnd)
    }
    for (_, incoming, transition) in layers.flatMap(\.transitions) {
      let half = MediaTime(seconds: transition.duration.seconds / 2)
      edges.insert(max(incoming.timelineStart - half, .zero))
      edges.insert(min(incoming.timelineStart + half, duration))
    }
    let sorted = edges.sorted()
    return zip(sorted, sorted.dropFirst()).map { start, end in
      let video = layers.flatMap { layer -> [CompositionLayer] in
        if let crossing = layer.crossing(at: start) {
          return crossing
        }
        guard let placed = layer.clips.first(where: { $0.clip.contains(start) }) else {
          return []
        }
        return layer.layer(for: placed, fromHandles: false, transition: nil).map { [$0] } ?? []
      }
      let words = text.compactMap { clips in
        clips.first { $0.contains(start) }.map { CompositionLayer(
          clipID: $0.id,
          source: .text,
          matteTrackID: nil,
          flowTrackID: nil,
          transition: nil,
        ) }
      }
      let showing = video + words
      return CompositionInstruction(
        timeRange: CMTimeRange(start: start.cmTime, end: end.cmTime),
        layers: showing,
        pictureSize: pictureSize,
        isCanvas: isCanvas,
        renderState: renderState,
        renderContext: renderContext,
        frameCounter: frameCounter,
        quality: quality,
      )
    }
  }

}

// MARK: - VideoLayer

/// A timeline track's video in the composition (none when it holds only stills), its cut-outs'
/// track and its transitions' handle track if any, and its transitions.
private struct VideoLayer {

  let trackID: CMPersistentTrackID?
  let matteTrackID: CMPersistentTrackID?
  let flowTrackID: CMPersistentTrackID?
  let handleTrackID: CMPersistentTrackID?
  let clips: [PlacedClip]
  let transitions: [(outgoing: Clip, incoming: Clip, transition: Transition)]

  /// Both clips of a transition happening at `start`, outgoing below incoming, or `nil` when
  /// none is.
  func crossing(at start: MediaTime) -> [CompositionLayer]? {
    for (outgoing, incoming, transition) in transitions {
      let half = MediaTime(seconds: transition.duration.seconds / 2)
      let cut = incoming.timelineStart
      guard
        cut - half <= start, start < cut + half,
        let leaving = clips.first(where: { $0.clip.id == outgoing.id }),
        let arriving = clips.first(where: { $0.clip.id == incoming.id })
      else {
        continue
      }
      let part = { (isIncoming: Bool) in
        TransitionPart(
          kind: transition.kind,
          start: cut - half,
          duration: transition.duration,
          isIncoming: isIncoming,
        )
      }
      return [
        layer(for: leaving, fromHandles: start >= cut, transition: part(false)),
        layer(for: arriving, fromHandles: start < cut, transition: part(true)),
      ].compactMap(\.self)
    }
    return nil
  }

  /// How `placed` is drawn: from its own track, or from the handles while a transition shows it
  /// past its edge.
  func layer(
    for placed: PlacedClip,
    fromHandles: Bool,
    transition: TransitionPart?,
  ) -> CompositionLayer? {
    let videoTrack = fromHandles ? handleTrackID : trackID
    guard
      let source = placed.drawn
      ?? videoTrack.map({ LayerSource.video(trackID: $0, rotation: placed.rotation) })
    else {
      return nil
    }
    return CompositionLayer(
      clipID: placed.clip.id,
      source: source,
      matteTrackID: placed.hasMatte && !fromHandles ? matteTrackID : nil,
      flowTrackID: placed.hasFlow && !fromHandles ? flowTrackID : nil,
      transition: transition,
    )
  }

}

// MARK: - PlacedClip

/// A clip placed in the composition: its rotation, whether its cut-out and optical flow came
/// with it, and how it's drawn when it isn't video (a still or a drawing).
private struct PlacedClip {

  // MARK: Lifecycle

  init(
    clip: Clip,
    rotation: CGAffineTransform,
    hasMatte: Bool,
    hasFlow: Bool = false,
    drawn: LayerSource?,
  ) {
    self.clip = clip
    self.rotation = rotation
    self.hasMatte = hasMatte
    self.hasFlow = hasFlow
    self.drawn = drawn
  }

  // MARK: Internal

  let clip: Clip
  let rotation: CGAffineTransform
  let hasMatte: Bool
  let hasFlow: Bool
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

  // MARK: Lifecycle

  init(_ clip: Clip) {
    id = clip.id
    mediaID = clip.mediaID
    sourceStart = clip.sourceStart
    duration = clip.duration
    timelineStart = clip.timelineStart
    transitionLength = clip.transitionIn?.duration
    cleanSound = clip.cleanSound
    speed = clip.speed
    speedKeyframes = clip.keyframes.filter { $0.property == .speed }
  }

  // MARK: Internal

  let id: Clip.ID
  let mediaID: Media.ID?
  let sourceStart: MediaTime
  let duration: MediaTime
  let timelineStart: MediaTime
  /// How long its incoming transition lasts: it decides the handles.
  let transitionLength: MediaTime?
  /// Whether it plays its media's noise-reduced sound: a different source file.
  let cleanSound: Bool
  /// How fast it plays: it decides which stretches of media go where.
  let speed: Double
  let speedKeyframes: [Keyframe]

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
