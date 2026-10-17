import Foundation

// MARK: - Transcript

/// What was said in a media file, with word timings in the file's own time.
public struct Transcript: Codable, Hashable, Sendable {
  public init(segments: [TranscriptSegment], language: String?) {
    self.segments = segments
    self.language = language
  }

  /// Phrases in time order.
  public var segments: [TranscriptSegment]
  /// The spoken language's code, e.g. "en" or "hi".
  public var language: String?

  /// Every word in time order.
  public var words: [TranscriptWord] {
    segments.flatMap(\.words)
  }
}

// MARK: - TranscriptSegment

/// One phrase: its text and words.
public struct TranscriptSegment: Codable, Hashable, Sendable {
  public init(text: String, start: MediaTime, end: MediaTime, words: [TranscriptWord]) {
    self.text = text
    self.start = start
    self.end = end
    self.words = words
  }

  public var text: String
  public var start: MediaTime
  public var end: MediaTime
  public var words: [TranscriptWord]
}

// MARK: - TranscriptWord

/// One spoken word and when it was said, in the media file's time.
public struct TranscriptWord: Codable, Hashable, Sendable {
  public init(text: String, start: MediaTime, end: MediaTime) {
    self.text = text
    self.start = start
    self.end = end
  }

  public var text: String
  public var start: MediaTime
  public var end: MediaTime
}
