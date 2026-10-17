import Foundation

/// Cleans recognizer output into transcript text: removes special tokens like `<|en|>`,
/// non-speech markers like "[Music]" or "*laughs*", music symbols and stray whitespace. Ported
/// from Nebula.
enum TranscriptText {

  /// Removes markup from consecutive pieces of text (like the words of one phrase), remembering
  /// open brackets across pieces so "[", "Music", "]" are all dropped.
  struct Stripper {

    // MARK: Internal

    mutating func strip(_ text: String) -> String {
      let withoutTokens = text.replacing(/<\|[^|>]*\|>/, with: "").replacing(">>", with: "")
      var output = ""
      for character in withoutTokens {
        switch character {
        case "[",
             "(",
             "{": depth += 1
        case "]",
             ")",
             "}": depth = max(0, depth - 1)
        case "*": inAsterisks.toggle()
        case "♪",
             "♫",
             "♬",
             "🎵",
             "🎶": continue
        default:
          if depth == 0, !inAsterisks {
            output.append(character)
          }
        }
      }
      return output
    }

    // MARK: Private

    private var depth = 0
    private var inAsterisks = false

  }

  /// Collapses whitespace, removes spaces before punctuation and trims. Returns "" when nothing
  /// speakable (no letter or digit) is left.
  static func normalize(_ text: String) -> String {
    var result = text.replacing(/\s+/, with: " ")
    result = result.replacing(/\s+([,.!?;:…%])/) { String($0.output.1) }
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    while let first = result.first, ",;:".contains(first) {
      result.removeFirst()
      result = result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return result.contains { $0.isLetter || $0.isNumber } ? result : ""
  }

}
