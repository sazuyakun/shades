import Foundation

/// A named point on the timeline.
public struct Marker: Codable, Hashable, Sendable, Identifiable {
  public init(id: UUID = UUID(), time: MediaTime, name: String = "") {
    self.id = id
    self.time = time
    self.name = name
  }

  public let id: UUID
  public var time: MediaTime
  public var name: String
}
