import Foundation

/// A horizontal lane of clips. Clips are kept sorted by start time and never overlap.
public struct Track: Codable, Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    kind: TrackKind,
    clips: [Clip] = [],
    isMuted: Bool = false,
    isHidden: Bool = false,
  ) {
    self.id = id
    self.kind = kind
    self.clips = clips
    self.isMuted = isMuted
    self.isHidden = isHidden
  }

  // MARK: Public

  public let id: UUID
  public let kind: TrackKind
  public var clips: [Clip]
  /// Silences the track's sound.
  public var isMuted: Bool
  /// Hides the track's pictures.
  public var isHidden: Bool

  /// The time right after the last clip on this track.
  public var end: MediaTime {
    clips.last?.timelineEnd ?? .zero
  }

  /// The clip playing at `time`, if any.
  public func clip(at time: MediaTime) -> Clip? {
    clips.first { $0.contains(time) }
  }

}
