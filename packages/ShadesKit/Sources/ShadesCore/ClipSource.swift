import Foundation

/// What a clip shows: part of a media file, or text drawn by Shades.
public enum ClipSource: Codable, Hashable, Sendable {
  case media(Media.ID)
  case text(TextContent)
}
