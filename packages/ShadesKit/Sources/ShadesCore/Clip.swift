import Foundation

/// A piece of a media file placed on a track, with how it's drawn and heard.
public struct Clip: Codable, Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

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
    self.id = id
    self.mediaID = mediaID
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
  public let mediaID: Media.ID
  /// Where in the media file the clip begins.
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

  /// Where on the timeline the clip ends.
  public var timelineEnd: MediaTime {
    timelineStart + duration
  }

  /// Whether `time` falls inside the clip (its start included, its end not).
  public func contains(_ time: MediaTime) -> Bool {
    timelineStart <= time && time < timelineEnd
  }

}
