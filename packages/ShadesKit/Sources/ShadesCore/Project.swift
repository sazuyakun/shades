import Foundation

/// Everything the user is editing: imported media and the timeline built from it.
public struct Project: Codable, Hashable, Sendable {
  public init(media: [Media] = [], timeline: Timeline = Timeline()) {
    self.media = media
    self.timeline = timeline
  }

  public var media: [Media]
  public var timeline: Timeline

  /// Looks up imported media by its ID.
  public func media(withID id: Media.ID) -> Media? {
    media.first { $0.id == id }
  }
}
