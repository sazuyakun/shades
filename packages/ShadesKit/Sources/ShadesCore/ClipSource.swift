import Foundation

// MARK: - ClipSource

/// What a clip shows: part of a media file, or text drawn by Shades.
public enum ClipSource: Codable, Hashable, Sendable {
  case media(Media.ID)
  case text(TextContent)
}

// MARK: - TextContent

/// The words a text clip shows. Styling grows with the type engine; captions use the default.
public struct TextContent: Codable, Hashable, Sendable {
  public init(text: String) {
    self.text = text
  }

  public var text: String
}
