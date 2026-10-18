import Foundation
import ShadesCore

// MARK: - PolishPlan

/// What Polish proposes for a stretch of the timeline: a list of small edits to review, toggle
/// and apply in one go.
public struct PolishPlan: Sendable, Hashable, Identifiable {
  public let id: UUID
  /// The stretch Polish looked at.
  public let range: TimeRange
  /// The track the speech is on, e.g. "V1".
  public let track: String
  public var items: [PolishItem]

  /// How many items of each kind are switched on.
  public func enabledCount(of kind: PolishKind) -> Int {
    items.count { $0.kind == kind && $0.isEnabled }
  }
}

// MARK: - PolishItem

/// One proposed edit.
public struct PolishItem: Sendable, Hashable, Identifiable {
  public let id: UUID
  public let kind: PolishKind
  /// For cuts, the time removed; for a beat snap, the cut's new position as a moment; for a
  /// punch-in, the stretch that gets zoomed.
  public let range: TimeRange
  /// In plain words, e.g. "1.4 s pause" or "“um”".
  public let detail: String
  public var isEnabled = true
}

// MARK: - PolishKind

/// The kinds of edit Polish makes.
public enum PolishKind: String, CaseIterable, Sendable, Codable {
  case silence
  case filler
  case retake
  case beatSnap
  case punchIn

  // MARK: Public

  /// The group's name in the checklist.
  public var title: String {
    switch self {
    case .silence: "Cut silences"
    case .filler: "Cut fillers"
    case .retake: "Remove retakes"
    case .beatSnap: "Snap cuts to beats"
    case .punchIn: "Punch in on jump cuts"
    }
  }

  /// Whether the item removes time from the track.
  public var isCut: Bool {
    self == .silence || self == .filler || self == .retake
  }
}
