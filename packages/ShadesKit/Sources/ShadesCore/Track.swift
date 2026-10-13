import Foundation

/// A horizontal lane of clips on the timeline.
public struct Track: Codable, Hashable, Sendable, Identifiable {
  public init(id: UUID = UUID(), name: String, clips: [Clip] = []) {
    self.id = id
    self.name = name
    self.clips = clips
  }

  public let id: UUID
  public let name: String
  public var clips: [Clip]

  /// The time right after the last clip on this track.
  public var end: MediaTime {
    clips.map(\.timelineEnd).max() ?? .zero
  }
}
