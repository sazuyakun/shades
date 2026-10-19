import Foundation

/// A named stretch of the master timeline, exported on its own on the vertical canvas.
public struct Short: Codable, Hashable, Sendable, Identifiable {
  public init(id: UUID = UUID(), name: String, range: TimeRange) {
    self.id = id
    self.name = name
    self.range = range
  }

  public let id: UUID
  public var name: String
  public var range: TimeRange
}
