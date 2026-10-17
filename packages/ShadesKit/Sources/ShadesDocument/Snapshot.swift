import Foundation

/// A saved version of a project: automatic, before a Claude request, or a named checkpoint.
public struct Snapshot: Hashable, Sendable, Identifiable {
  public let url: URL
  public let date: Date
  /// "Auto", "Before Claude", or the checkpoint's name.
  public let label: String

  public var id: URL {
    url
  }
}
