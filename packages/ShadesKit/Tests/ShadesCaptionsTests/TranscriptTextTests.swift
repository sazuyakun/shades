@testable import ShadesCaptions
import ShadesCore
import Testing

struct TranscriptTextTests {
  @Test
  func `markup, tokens and stray spaces are removed`() {
    var stripper = TranscriptText.Stripper()
    let raw = stripper.strip("<|en|> Hello [Music] there ♪ , friend *laughs*")
    #expect(TranscriptText.normalize(raw) == "Hello there, friend")
  }

  @Test
  func `brackets are remembered across words`() {
    var stripper = TranscriptText.Stripper()
    let words = ["[", "Music", "]", " Hi"].map { stripper.strip($0) }
    #expect(TranscriptText.normalize(words.joined()) == "Hi")
  }

  @Test
  func `text with nothing speakable is empty`() {
    #expect(TranscriptText.normalize(" ... - ") == "")
  }

  @Test
  func `a phrase keeps speakable words with times that never go backwards`() throws {
    let segment = RecognizedSegment(
      text: " Hello [Music] world",
      start: 1,
      end: 3,
      words: [
        .init(text: " Hello", start: 1, end: 1.5),
        .init(text: " [Music]", start: 1.5, end: 2),
        .init(text: " world", start: 1.4, end: 2.5),
      ],
    )
    let cleaned = try #require(segment.cleaned)
    #expect(cleaned.text == "Hello world")
    #expect(cleaned.words.map(\.text) == ["Hello", "world"])
    #expect(cleaned.words[1].start == MediaTime(seconds: 1.5, timescale: 1000))
  }
}
