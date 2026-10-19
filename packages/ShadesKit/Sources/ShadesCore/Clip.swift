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
  }

}
