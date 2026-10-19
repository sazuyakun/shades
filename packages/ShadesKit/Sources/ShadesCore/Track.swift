import Foundation

// MARK: - Track

/// A horizontal lane of clips. Clips are kept sorted by start time and never overlap.
public struct Track: Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    kind: TrackKind,
    clips: [Clip] = [],
    isMuted: Bool = false,
    isHidden: Bool = false,
    followsCamera: Bool? = nil,
  ) {
    self.id = id
    self.kind = kind
    self.clips = clips
    self.isMuted = isMuted
    self.isHidden = isHidden
    self.followsCamera = followsCamera ?? (kind != .text)
  }

  // MARK: Public

  public let id: UUID
  public let kind: TrackKind
  public var clips: [Clip]
  /// Silences the track's sound.
  public var isMuted: Bool
  /// Hides the track's pictures.
  public var isHidden: Bool
  /// Whether the timeline's camera moves this track's pictures (by default video does, text
  /// such as captions doesn't).
  public var followsCamera: Bool

  /// The time right after the last clip on this track.
  public var end: MediaTime {
    clips.last?.timelineEnd ?? .zero
  }

  /// The clip playing at `time`, if any.
  public func clip(at time: MediaTime) -> Clip? {
    clips.first { $0.contains(time) }
  }

}

// MARK: Codable

extension Track: Codable {

  // MARK: Lifecycle

  /// Reads a track, including ones saved before the camera existed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      kind: container.decode(TrackKind.self, forKey: .kind),
      clips: container.decode([Clip].self, forKey: .clips),
      isMuted: container.decode(Bool.self, forKey: .isMuted),
      isHidden: container.decode(Bool.self, forKey: .isHidden),
      followsCamera: container.decodeIfPresent(Bool.self, forKey: .followsCamera),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case kind
    case clips
    case isMuted
    case isHidden
    case followsCamera
  }

}
