import Foundation

/// What a clip shows: part of a media file, or text or hand-drawn lines drawn by Shades.
public enum ClipSource: Codable, Hashable, Sendable {
  case media(Media.ID)
  case text(TextContent)
  case drawing(Drawing)
  /// Changes everything under it with its grade and effects, for as long as it lasts.
  case adjustment
}
