import Foundation

/// A piece of a media file placed on a track.
public struct Clip: Codable, Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    mediaID: Media.ID,
    sourceStart: MediaTime,
    duration: MediaTime,
    timelineStart: MediaTime,
  ) {
    self.id = id
    self.mediaID = mediaID
    self.sourceStart = sourceStart
    self.duration = duration
    self.timelineStart = timelineStart
  }

  // MARK: Public

  public let id: UUID
  public let mediaID: Media.ID
  /// Where in the media file the clip begins.
  public let sourceStart: MediaTime
  public let duration: MediaTime
  /// Where on the timeline the clip begins.
  public let timelineStart: MediaTime

  /// Where on the timeline the clip ends.
  public var timelineEnd: MediaTime {
    timelineStart + duration
  }

}
