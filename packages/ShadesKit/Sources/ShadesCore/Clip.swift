import Foundation

/// A piece of a media file (or some text) placed on a track, with how it's drawn and heard.
public struct Clip: Codable, Hashable, Sendable, Identifiable {

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
