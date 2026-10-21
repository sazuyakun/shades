import Foundation
import ShadesCommands
import ShadesCore

/// One step of a Claude request: a tool call, or an edit a background job it started made later.
public struct ActivityEntry: Identifiable, Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    date: Date = .now,
    title: String,
    summary: String,
    isError: Bool,
    changedClipIDs: Set<UUID>,
    addedClipCount: Int = 0,
    removedClipCount: Int = 0,
    change: ProjectChange? = nil,
  ) {
    self.id = id
    self.date = date
    self.title = title
    self.summary = summary
    self.isError = isError
    self.changedClipIDs = changedClipIDs
    self.addedClipCount = addedClipCount
    self.removedClipCount = removedClipCount
    self.change = change
  }

  /// A step that took the project from `before` to `after`.
  public init(
    title: String,
    summary: String,
    isError: Bool,
    from before: Project,
    to after: Project,
  ) {
    let previous = Set(before.timeline.allClips)
    let oldIDs = Set(before.timeline.allClips.map(\.id))
    let newIDs = Set(after.timeline.allClips.map(\.id))
    self.init(
      title: title,
      summary: summary,
      isError: isError,
      changedClipIDs: Set(after.timeline.allClips.filter { !previous.contains($0) }.map(\.id)),
      addedClipCount: newIDs.subtracting(oldIDs).count,
      removedClipCount: oldIDs.subtracting(newIDs).count,
      change: ProjectChange(from: before, to: after),
    )
  }

  // MARK: Public

  public let id: UUID
  public let date: Date
  /// What Claude did, e.g. "Appended a clip".
  public let title: String
  /// The tool's result in plain words, or the error message.
  public let summary: String
  public let isError: Bool
  /// Clips this edit added or changed, so the timeline can highlight them.
  public let changedClipIDs: Set<UUID>
  /// How many clips this edit put on the timeline.
  public let addedClipCount: Int

  /// How many clips this edit took off the timeline.
  public let removedClipCount: Int
  /// What it changed, to take back later; `nil` when nothing changed.
  public let change: ProjectChange?

}
