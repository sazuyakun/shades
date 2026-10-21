import Foundation

// MARK: - Clip

/// A piece of a media file (or some text) placed on a track, with how it's drawn and heard.
public struct Clip: Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  /// A piece of a media file.
  public init(
    id: UUID = UUID(),
    mediaID: Media.ID,
    sourceStart: MediaTime,
    duration: MediaTime,
    timelineStart: MediaTime,
    transform: ClipTransform = .identity,
    opacity: Double = 1,
    depth: DepthSlot = .inFront,
    volume: Double = 1,
    isAudioEnabled: Bool = true,
    keyframes: [Keyframe] = [],
    sticker: StickerLook? = nil,
    grade: Grade? = nil,
    effects: Effects? = nil,
    blend: BlendMode = .normal,
    transitionIn: Transition? = nil,
    fadeIn: MediaTime = .zero,
    fadeOut: MediaTime = .zero,
    cleanSound: Bool = false,
    motionBlur: Double = 1,
    footageBlur: Bool = false,
  ) {
    self.init(
      id: id,
      source: .media(mediaID),
      sourceStart: sourceStart,
      duration: duration,
      timelineStart: timelineStart,
      transform: transform,
      opacity: opacity,
      depth: depth,
      volume: volume,
      isAudioEnabled: isAudioEnabled,
      keyframes: keyframes,
      sticker: sticker,
      grade: grade,
      effects: effects,
      blend: blend,
      transitionIn: transitionIn,
      fadeIn: fadeIn,
      fadeOut: fadeOut,
      cleanSound: cleanSound,
      motionBlur: motionBlur,
      footageBlur: footageBlur,
    )
  }

  /// Any clip, from what it shows.
  public init(
    id: UUID = UUID(),
    source: ClipSource,
    sourceStart: MediaTime,
    duration: MediaTime,
    timelineStart: MediaTime,
    transform: ClipTransform = .identity,
    opacity: Double = 1,
    depth: DepthSlot = .inFront,
    volume: Double = 1,
    isAudioEnabled: Bool = true,
    keyframes: [Keyframe] = [],
    sticker: StickerLook? = nil,
    grade: Grade? = nil,
    effects: Effects? = nil,
    blend: BlendMode = .normal,
    transitionIn: Transition? = nil,
    fadeIn: MediaTime = .zero,
    fadeOut: MediaTime = .zero,
    cleanSound: Bool = false,
    motionBlur: Double = 1,
    footageBlur: Bool = false,
  ) {
    self.id = id
    self.source = source
    self.sourceStart = sourceStart
    self.duration = duration
    self.timelineStart = timelineStart
    self.transform = transform
    self.opacity = opacity
    self.depth = depth
    self.volume = volume
    self.isAudioEnabled = isAudioEnabled
    self.keyframes = keyframes
    self.sticker = sticker
    self.grade = grade
    self.effects = effects
    self.blend = blend
    self.transitionIn = transitionIn
    self.fadeIn = fadeIn
    self.fadeOut = fadeOut
    self.cleanSound = cleanSound
    self.motionBlur = motionBlur
    self.footageBlur = footageBlur
  }

  // MARK: Public

  public let id: UUID
  public var source: ClipSource
  /// Where in the media file the clip begins (zero for text).
  public var sourceStart: MediaTime
  public var duration: MediaTime
  /// Where on the timeline the clip begins.
  public var timelineStart: MediaTime
  public var transform: ClipTransform
  /// 0 is invisible, 1 is solid.
  public var opacity: Double
  public var depth: DepthSlot
  /// Linear gain: 0 is silent, 1 is unchanged, 2 is twice as loud.
  public var volume: Double
  /// Whether a video clip plays its media's own sound (off once the audio is detached).
  public var isAudioEnabled: Bool
  /// Values that change over time, overriding the fixed ones while present.
  public var keyframes: [Keyframe]
  /// The die-cut sticker look, for still pictures with a see-through background.
  public var sticker: StickerLook?
  /// The clip's colour grade (for an adjustment clip, the grade of everything under it).
  public var grade: Grade?
  /// Film-look and keying effects.
  public var effects: Effects?
  /// How the clip mixes with what's under it.
  public var blend: BlendMode
  /// How the clip comes in from the clip just before it on its track (a cut when `nil`).
  public var transitionIn: Transition?
  /// How long the sound takes to rise from silence at the start.
  public var fadeIn: MediaTime
  /// How long the sound takes to fall to silence at the end.
  public var fadeOut: MediaTime
  /// Plays its media's noise-reduced sound, once it's been made.
  public var cleanSound: Bool
  /// How long the clip's motion blur is, as a share of the timeline's shutter: 1 follows the
  /// timeline, 0 is none, 2 twice as long.
  public var motionBlur: Double
  /// Also blurs movement inside the footage itself, along its optical flow, once that's made.
  public var footageBlur: Bool

  /// The media file the clip plays, unless it's text.
  public var mediaID: Media.ID? {
    if case .media(let id) = source {
      return id
    }
    return nil
  }

  /// The words a text clip shows, unless it plays media.
  public var text: TextContent? {
    if case .text(let content) = source {
      return content
    }
    return nil
  }

  /// The lines a drawing clip shows.
  public var drawing: Drawing? {
    if case .drawing(let drawing) = source {
      return drawing
    }
    return nil
  }

  /// Where on the timeline the clip ends.
  public var timelineEnd: MediaTime {
    timelineStart + duration
  }

  /// Whether `time` falls inside the clip (its start included, its end not).
  public func contains(_ time: MediaTime) -> Bool {
    timelineStart <= time && time < timelineEnd
  }

}

// MARK: Codable

extension Clip: Codable {

  // MARK: Lifecycle

  /// Reads a clip, including clips saved before text clips existed (a bare `mediaID`).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let source = try container.decodeIfPresent(ClipSource.self, forKey: .source)
      ?? .media(container.decode(Media.ID.self, forKey: .mediaID))
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      source: source,
      sourceStart: container.decode(MediaTime.self, forKey: .sourceStart),
      duration: container.decode(MediaTime.self, forKey: .duration),
      timelineStart: container.decode(MediaTime.self, forKey: .timelineStart),
      transform: container.decode(ClipTransform.self, forKey: .transform),
      opacity: container.decode(Double.self, forKey: .opacity),
      depth: container.decode(DepthSlot.self, forKey: .depth),
      volume: container.decode(Double.self, forKey: .volume),
      isAudioEnabled: container.decode(Bool.self, forKey: .isAudioEnabled),
      keyframes: container.decodeIfPresent([Keyframe].self, forKey: .keyframes) ?? [],
      sticker: container.decodeIfPresent(StickerLook.self, forKey: .sticker),
      grade: container.decodeIfPresent(Grade.self, forKey: .grade),
      effects: container.decodeIfPresent(Effects.self, forKey: .effects),
      blend: container.decodeIfPresent(BlendMode.self, forKey: .blend) ?? .normal,
      transitionIn: container.decodeIfPresent(Transition.self, forKey: .transitionIn),
      fadeIn: container.decodeIfPresent(MediaTime.self, forKey: .fadeIn) ?? .zero,
      fadeOut: container.decodeIfPresent(MediaTime.self, forKey: .fadeOut) ?? .zero,
      cleanSound: container.decodeIfPresent(Bool.self, forKey: .cleanSound) ?? false,
      motionBlur: container.decodeIfPresent(Double.self, forKey: .motionBlur) ?? 1,
      footageBlur: container.decodeIfPresent(Bool.self, forKey: .footageBlur) ?? false,
    )
  }

  // MARK: Public

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(source, forKey: .source)
    try container.encode(sourceStart, forKey: .sourceStart)
    try container.encode(duration, forKey: .duration)
    try container.encode(timelineStart, forKey: .timelineStart)
    try container.encode(transform, forKey: .transform)
    try container.encode(opacity, forKey: .opacity)
    try container.encode(depth, forKey: .depth)
    try container.encode(volume, forKey: .volume)
    try container.encode(isAudioEnabled, forKey: .isAudioEnabled)
    try container.encode(keyframes, forKey: .keyframes)
    try container.encodeIfPresent(sticker, forKey: .sticker)
    try container.encodeIfPresent(grade, forKey: .grade)
    try container.encodeIfPresent(effects, forKey: .effects)
    try container.encode(blend, forKey: .blend)
    try container.encodeIfPresent(transitionIn, forKey: .transitionIn)
    try container.encode(fadeIn, forKey: .fadeIn)
    try container.encode(fadeOut, forKey: .fadeOut)
    try container.encode(cleanSound, forKey: .cleanSound)
    try container.encode(motionBlur, forKey: .motionBlur)
    try container.encode(footageBlur, forKey: .footageBlur)
  }

  // MARK: Private

  private enum CodingKeys: String, CodingKey {
    case id
    case source
    /// Where clips saved before text clips existed kept their media.
    case mediaID
    case sourceStart
    case duration
    case timelineStart
    case transform
    case opacity
    case depth
    case volume
    case isAudioEnabled
    case keyframes
    case sticker
    case grade
    case effects
    case blend
    case transitionIn
    case fadeIn
    case fadeOut
    case cleanSound
    case motionBlur
    case footageBlur
  }

}
