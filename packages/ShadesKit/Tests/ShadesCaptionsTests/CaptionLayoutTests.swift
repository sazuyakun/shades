import Foundation
import ShadesCaptions
import ShadesCore
import Testing

struct CaptionLayoutTests {

  // MARK: Internal

  @Test
  func `short speech is one line spanning its words`() {
    let lines = CaptionLayout.lines(for: words([("Hello", 0), ("there", 0.4)]))
    #expect(lines.map(\.text) == ["Hello there"])
    #expect(lines[0].start == MediaTime(seconds: 0))
    #expect(lines[0].end == MediaTime(seconds: 0.7))
  }

  @Test
  func `sentences and pauses start new lines`() {
    let lines = CaptionLayout.lines(for: words([
      ("Hi.", 0),
      ("Next", 0.4),
      ("one", 0.8),
      ("after", 3),
      ("pause", 3.4),
    ]))
    #expect(lines.map(\.text) == ["Hi.", "Next one", "after pause"])
  }

  @Test
  func `long runs split into balanced lines within the limit`() {
    let text = "this is a rather long sentence that keeps going without any stop at all"
    let spoken = words(text.split(separator: " ").enumerated()
      .map { (String($1), Double($0) * 0.3) })
    let lines = CaptionLayout.lines(for: spoken, maxCharacters: 30)
    #expect(lines.count == 3)
    #expect(lines.allSatisfy { $0.text.count <= 30 })
    #expect(lines.map(\.text).joined(separator: " ") == text)
  }

  // MARK: Private

  private let clipID = UUID()

  private func words(_ items: [(String, Double)]) -> [SpokenWord] {
    items.map { text, start in
      SpokenWord(
        text: text,
        start: MediaTime(seconds: start),
        end: MediaTime(seconds: start + 0.3),
        clipID: clipID,
      )
    }
  }

}
