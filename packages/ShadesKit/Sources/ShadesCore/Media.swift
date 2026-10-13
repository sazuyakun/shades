import Foundation

/// A source file imported into the project. The file stays where it is on disk.
public struct Media: Codable, Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    url: URL,
    duration: MediaTime,
    width: Int,
    height: Int,
    hasAudio: Bool,
  ) {
    self.id = id
    self.url = url
    self.duration = duration
    self.width = width
    self.height = height
    self.hasAudio = hasAudio
  }

  // MARK: Public

  public let id: UUID
  public let url: URL
  public let duration: MediaTime
  public let width: Int
  public let height: Int
  public let hasAudio: Bool

  /// The file name without its extension, shown in the browser and timeline.
  public var name: String {
    url.deletingPathExtension().lastPathComponent
  }

}
