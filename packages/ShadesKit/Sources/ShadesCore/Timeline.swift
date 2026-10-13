import Foundation

/// An edit made of tracks, shown to the user as a "sequence" (`Sequence` is taken by Swift).
public struct Timeline: Codable, Hashable, Sendable {
  public init(name: String = "Main", tracks: [Track] = [Track(name: "V1")]) {
    self.name = name
    self.tracks = tracks
  }

  public let name: String
  public var tracks: [Track]

  /// The length of the whole edit.
  public var duration: MediaTime {
    tracks.map(\.end).max() ?? .zero
  }
}
