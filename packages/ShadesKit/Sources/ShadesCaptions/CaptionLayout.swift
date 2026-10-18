import ShadesCore

// MARK: - CaptionLayout

/// Splits spoken words into caption-sized lines: never longer than `maxCharacters` or 7 seconds,
/// breaking at sentence ends and pauses first, then into lines of balanced length. Ported from
/// Nebula.
public enum CaptionLayout {

  // MARK: Public

  /// Caption lines for `words` (in time order). A line stays up until the next one when the gap
  /// is shorter than a second, so captions don't flicker between lines.
  public static func lines(for words: [SpokenWord], maxCharacters: Int = 42) -> [CaptionLine] {
    let lines = packedLines(for: words, limit: max(1, maxCharacters))
    return lines.enumerated().map { index, line in
      guard index + 1 < lines.count, (lines[index + 1].start - line.end).seconds < holdGap else {
        return line
      }
      return CaptionLine(text: line.text, start: line.start, end: lines[index + 1].start)
    }
  }

  // MARK: Private

  /// Gaps shorter than this between lines are bridged by holding the earlier line.
  private static let holdGap = 1.0

  /// Longest a line stays up, in seconds.
  private static let maxLineDuration = 7.0
  /// A pause at least this long between words starts a new line.
  private static let pauseBreak = 0.8

  private static func packedLines(for words: [SpokenWord], limit: Int) -> [CaptionLine] {
    runs(of: words).flatMap { pack($0, limit: limit) }.compactMap { line in
      guard let first = line.first, let last = line.last else {
        return nil
      }
      return CaptionLine(
        text: line.map(\.text).joined(separator: " "),
        start: first.start,
        end: max(last.end, first.start),
      )
    }
  }

  /// Splits words into runs that never share a line: after sentence ends and long pauses.
  private static func runs(of words: [SpokenWord]) -> [[SpokenWord]] {
    var runs = [[SpokenWord]]()
    var current = [SpokenWord]()
    for (index, word) in words.enumerated() {
      current.append(word)
      guard index + 1 < words.count else {
        break
      }
      let next = words[index + 1]
      if endsSentence(word.text) || (next.start - word.end).seconds >= pauseBreak {
        runs.append(current)
        current = []
      }
    }
    if !current.isEmpty {
      runs.append(current)
    }
    return runs
  }

  private static func endsSentence(_ word: String) -> Bool {
    word.last.map { ".?!…।".contains($0) } ?? false
  }

  /// Packs a run into lines of at most `limit` characters, balancing their lengths.
  private static func pack(_ run: [SpokenWord], limit: Int) -> [[SpokenWord]] {
    var lines = [[SpokenWord]]()
    var index = 0
    while index < run.count {
      let remaining = run[index...].reduce(0) { $0 + $1.text.count } + run.count - index - 1
      let lineCount = Int((Double(remaining) / Double(limit)).rounded(.up))
      let target = lineCount > 1 ? Int((Double(remaining) / Double(lineCount)).rounded(.up)) : limit
      var line = [run[index]]
      var length = run[index].text.count
      index += 1
      while index < run.count {
        let word = run[index]
        let next = length + 1 + word.text.count
        if
          next > limit || (next > target && next - target > target - length)
          || (word.end - line[0].start).seconds > maxLineDuration
        {
          break
        }
        line.append(word)
        length = next
        index += 1
      }
      lines.append(line)
    }
    return lines
  }

}

// MARK: - CaptionLine

/// One caption: its words and when it shows, in timeline time.
public struct CaptionLine: Hashable, Sendable {
  public let text: String
  public let start: MediaTime
  public let end: MediaTime
}
