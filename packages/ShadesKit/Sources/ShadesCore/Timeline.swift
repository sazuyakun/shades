import Foundation

/// An edit made of tracks, shown to the user as a "sequence" (`Sequence` is taken by Swift).
public struct Timeline: Codable, Hashable, Sendable {
  public init(
    name: String = "Main",
    format: VideoFormat = .youTube4x3,
    tracks: [Track] = [Track(name: "V1")],
  ) {
    self.name = name
    self.format = format
    self.tracks = tracks
  }

  public let name: String
  /// The size and frame rate this edit plays and exports at, whatever its clips' sizes.
  public var format: VideoFormat
  public var tracks: [Track]

  /// The length of the whole edit.
  public var duration: MediaTime {
    tracks.map(\.end).max() ?? .zero
  }
}
