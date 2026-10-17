import Foundation
import Observation

/// Everything Claude changed over MCP, newest first, plus the edit it made a moment ago (toasted,
/// with its clips glowing purple on the timeline, then fading).
@MainActor
@Observable
public final class ActivityLog {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// How long the latest edit stays announced and its clips stay highlighted.
  public static let highlightDuration = Duration.seconds(3)

  public private(set) var entries = [ActivityEntry]()
  /// The edit Claude just made, until `highlightDuration` passes; the UI toasts it.
  public private(set) var recentEntry: ActivityEntry?

  /// Clips the recent edit changed, so the timeline can make them glow.
  public var recentlyChangedClipIDs: Set<UUID> {
    recentEntry?.changedClipIDs ?? []
  }

  // MARK: Internal

  /// Adds an entry and keeps it as the recent one until `highlightDuration` passes.
  func record(_ entry: ActivityEntry) {
    entries.insert(entry, at: 0)
    recentEntry = entry
    Task {
      try? await Task
        .sleep(for: Self.highlightDuration) // why: a cancelled sleep just clears sooner.
      if recentEntry?.id == entry.id {
        recentEntry = nil
      }
    }
  }

}
