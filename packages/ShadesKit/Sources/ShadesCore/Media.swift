import Foundation

// MARK: - Media

/// A source file imported into the project. The file stays where it is on disk.
public struct Media: Hashable, Sendable, Identifiable {

  // MARK: Lifecycle

  public init(
    id: UUID = UUID(),
    url: URL,
    duration: MediaTime,
    width: Int,
    height: Int,
    hasVideo: Bool = true,
    hasAudio: Bool,
    isStill: Bool = false,
    color: VideoColor? = nil,
  ) {
    self.id = id
    self.url = url
    self.duration = duration
    self.width = width
    self.height = height
    self.hasVideo = hasVideo
    self.hasAudio = hasAudio
    self.isStill = isStill
    self.color = color
  }

  // MARK: Public

  /// How long a still is placed for unless asked otherwise.
  public static let stillLength = MediaTime(seconds: 5)

  public let id: UUID
  public let url: URL
  public let duration: MediaTime
  public let width: Int
  public let height: Int
  public let hasVideo: Bool
  public let hasAudio: Bool
  /// A picture rather than a video (a PNG sticker, a photo): it can be placed for any length.
  public let isStill: Bool
  /// How the video's colours are encoded, from its file's tags; `nil` for sound, stills and
  /// media imported before colour was read.
  public let color: VideoColor?

  /// The file name without its extension, shown in the browser and timeline.
  public var name: String {
    url.deletingPathExtension().lastPathComponent
  }

  /// How long the media is on a timeline at `framesPerSecond`: its duration to the nearest
  /// frame. The one rounding rule for a file's end, so a whole sound ends on the same frame as
  /// its video; a clip can run under half a frame past its file, which plays as silence.
  public func length(at framesPerSecond: Int) -> MediaTime {
    duration.roundedToFrame(at: framesPerSecond)
  }

}

// MARK: Codable

extension Media: Codable {

  // MARK: Lifecycle

  /// Reads media, including media saved before stills (always video or sound) or colour tags.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      id: container.decode(UUID.self, forKey: .id),
      url: container.decode(URL.self, forKey: .url),
      duration: container.decode(MediaTime.self, forKey: .duration),
      width: container.decode(Int.self, forKey: .width),
      height: container.decode(Int.self, forKey: .height),
      hasVideo: container.decode(Bool.self, forKey: .hasVideo),
      hasAudio: container.decode(Bool.self, forKey: .hasAudio),
      isStill: container.decodeIfPresent(Bool.self, forKey: .isStill) ?? false,
      color: container.decodeIfPresent(VideoColor.self, forKey: .color),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case id
    case url
    case duration
    case width
    case height
    case hasVideo
    case hasAudio
    case isStill
    case color
  }

}
