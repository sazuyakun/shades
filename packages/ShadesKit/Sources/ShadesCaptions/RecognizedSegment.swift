import Foundation
import ShadesCore

/// A phrase as the recognizer reports it, before cleaning. Times are in seconds.
struct RecognizedSegment: Sendable, Hashable {

  // MARK: Internal

  /// A recognized word; `text` keeps its leading space, if any.
  struct Word: Sendable, Hashable {
    var text: String
    var start: Double
    var end: Double
  }

  var text: String
  var start: Double
  var end: Double
  var words: [Word]

  /// The cleaned phrase, or `nil` when nothing speakable is left. Word times never go backwards.
  /// Ported from Nebula's segment builder.
  var cleaned: TranscriptSegment? {
    var stripper = TranscriptText.Stripper()
    var cleanedWords = [TranscriptWord]()
    var joined = ""
    var previousEnd = -Double.infinity
    for word in words {
      let stripped = stripper.strip(word.text)
      let text = TranscriptText.normalize(stripped)
      guard !text.isEmpty else {
        continue
      }
      let start = max(word.start, previousEnd)
      let end = max(start, word.end)
      if !joined.isEmpty, stripped.first?.isWhitespace ?? false {
        joined += " "
      }
      joined += text
      cleanedWords.append(TranscriptWord(text: text, start: Self.time(start), end: Self.time(end)))
      previousEnd = end
    }
    let text = TranscriptText.normalize(joined)
    guard let first = cleanedWords.first, let last = cleanedWords.last, !text.isEmpty else {
      return nil
    }
    let end = last.end > first.start ? last.end : Self.time(max(end, first.start.seconds + 0.2))
    return TranscriptSegment(text: text, start: first.start, end: end, words: cleanedWords)
  }

  // MARK: Private

  /// Seconds as a time with millisecond precision.
  private static func time(_ seconds: Double) -> MediaTime {
    MediaTime(seconds: seconds, timescale: 1000)
  }

}
