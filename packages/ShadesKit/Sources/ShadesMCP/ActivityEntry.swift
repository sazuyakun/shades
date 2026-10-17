import Foundation

/// One edit Claude made over MCP, as shown in the History pane.
public struct ActivityEntry: Identifiable, Sendable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    date: Date = .now,
    title: String,
    summary: String,
    isError: Bool,
    changedClipIDs: Set<UUID>,
  ) {
    self.id = id
    self.date = date
    self.title = title
    self.summary = summary
    self.isError = isError
    self.changedClipIDs = changedClipIDs
  }

  // MARK: Public

  public let id: UUID
  public let date: Date
  /// What Claude did, e.g. "Appended a clip".
  public let title: String
  /// The tool's result in plain words, or the error message.
  public let summary: String
  public let isError: Bool
  /// Clips this edit added, so the timeline can highlight them.
  public let changedClipIDs: Set<UUID>

}
