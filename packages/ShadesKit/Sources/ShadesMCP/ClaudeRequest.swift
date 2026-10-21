import Foundation

/// One thing the user asked Claude for: the edits Claude made for it, plus edits that background
/// jobs it started made later. The History pane shows each and undoes it as a whole.
public struct ClaudeRequest: Identifiable, Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(id: UUID = UUID(), name: String? = nil, date: Date = .now) {
    self.id = id
    self.name = name
    self.date = date
    lastActive = date
  }

  // MARK: Public

  public let id: UUID
  /// What the user asked, as Claude named it (`start_request`), if it did.
  public var name: String?
  /// When it started.
  public let date: Date
  /// When Claude last called a tool for it.
  public var lastActive: Date
  /// What was done, oldest first.
  public var steps = [ActivityEntry]()
  /// The file name of the snapshot saved just before it, to revert to.
  public var snapshot: String?

  /// Its name, or else what its first step did.
  public var title: String {
    name ?? steps.first?.title ?? "Claude"
  }

  /// Clips it added or changed, some perhaps gone since.
  public var changedClipIDs: Set<UUID> {
    steps.reduce(into: []) { $0.formUnion($1.changedClipIDs) }
  }

  /// How many clips it put on the timeline.
  public var addedClipCount: Int {
    steps.map(\.addedClipCount).reduce(0, +)
  }

  /// How many clips it took away.
  public var removedClipCount: Int {
    steps.map(\.removedClipCount).reduce(0, +)
  }

  /// Whether it changed the project at all.
  public var hasChanges: Bool {
    steps.contains { $0.change != nil }
  }

}
