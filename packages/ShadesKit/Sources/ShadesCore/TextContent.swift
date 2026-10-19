import Foundation

// MARK: - TextContent

/// The words a text clip shows, how they look, and how they come on screen.
public struct TextContent: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    text: String,
    style: TextStyle = .caption,
    words: [TimedWord]? = nil,
    reveal: TextReveal = .none,
  ) {
    self.text = text
    self.style = style
    self.words = words
    self.reveal = reveal
  }

  // MARK: Public

  public var text: String
  public var style: TextStyle
  /// When each word is said (from the transcript), for revealing them in time.
  public var words: [TimedWord]?
  public var reveal: TextReveal

}

// MARK: Codable

extension TextContent: Codable {

  // MARK: Lifecycle

  /// Reads text, including text saved before it had a style (the caption look).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      text: container.decode(String.self, forKey: .text),
      style: container.decodeIfPresent(TextStyle.self, forKey: .style) ?? .caption,
      words: container.decodeIfPresent([TimedWord].self, forKey: .words),
      reveal: container.decodeIfPresent(TextReveal.self, forKey: .reveal) ?? .none,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case text
    case style
    case words
    case reveal
  }

}
