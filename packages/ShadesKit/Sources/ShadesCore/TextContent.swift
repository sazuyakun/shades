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
    word: Int? = nil,
    path: TextPath? = nil,
  ) {
    self.text = text
    self.style = style
    self.words = words
    self.reveal = reveal
    self.word = word
    self.path = path
  }

  // MARK: Public

  public var text: String
  public var style: TextStyle
  /// When each word is said (from the transcript), for revealing them in time.
  public var words: [TimedWord]?
  public var reveal: TextReveal
  /// The one word this clip shows (counting from 0), where it sits in the whole text: a
  /// per-word layer. `nil` shows every word.
  public var word: Int?
  /// The path the text follows, instead of sitting in lines.
  public var path: TextPath?

  /// The text's words, split on spaces.
  public var wordList: [Substring] {
    text.split(separator: " ", omittingEmptySubsequences: true)
  }

  /// What the clip shows: its one word, or all of its text.
  public var shownText: String {
    let words = wordList
    return word.flatMap { words.indices.contains($0) ? String(words[$0]) : nil } ?? text
  }

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
      word: container.decodeIfPresent(Int.self, forKey: .word),
      path: container.decodeIfPresent(TextPath.self, forKey: .path),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case text
    case style
    case words
    case reveal
    case word
    case path
  }

}
