import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Styled text and kinetic reveals, drawn by the compositor.
struct TextRenderingTests {

  // MARK: Internal

  @Test
  func `popping words appear as they're said and grow into place`() {
    let content = TextContent(text: "one two three", words: words, reveal: .pop)
    let early = TextRenderer.wordStates(of: content, at: 0.51, duration: 2).states
    #expect(early.map { $0.alpha > 0 } == [true, true, false])
    #expect(early[0].scale == 1)
    #expect(early[1].scale < 1)
    let late = TextRenderer.wordStates(of: content, at: 1.9, duration: 2).states
    #expect(late.allSatisfy { $0.alpha == 1 && abs($0.scale - 1) < 0.01 })
  }

  @Test
  func `highlight lights up only the word being said`() {
    let content = TextContent(text: "one two three", words: words, reveal: .highlight)
    let states = TextRenderer.wordStates(of: content, at: 0.6, duration: 2).states
    #expect(states.map(\.isSaid) == [false, true, false])
    #expect(states.allSatisfy { $0.alpha == 1 })
  }

  @Test
  func `typewriter types each word's letters over its time`() {
    let content = TextContent(text: "one two three", words: words, reveal: .typewriter)
    let states = TextRenderer.wordStates(of: content, at: 0.75, duration: 2).states
    #expect(states.map(\.letters) == [3, 1, 0])
  }

  @Test
  func `without word timings the words are spread over the clip's start`() {
    let content = TextContent(text: "a b c d", reveal: .pop)
    let states = TextRenderer.wordStates(of: content, at: 0.35, duration: 4).states
    #expect(states.map { $0.alpha > 0 } == [true, true, false, false])
  }

  @Test
  func `a centred title is drawn in its colour in the middle of the frame`() async throws {
    let style = TextStyle(size: 0.2, color: HexColor("#FFD84A") ?? .white, anchor: .center)
    let png = try await frame(TextContent(text: "SHADES", style: style), at: 0.5)
    let letter = try PixelProbe.color(of: png, x: 0.24, y: 0.5)
    #expect(letter.red > 230 && letter.green > 190 && letter.blue < 120)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.85).blue > 200)
    #expect(try GoldenFrame.matches(png, named: "title-centered", in: golden))
  }

  @Test
  func `a title scales about its own centre`() async throws {
    let style = TextStyle(size: 0.12, anchor: .center)
    var content = TextContent(text: "SHADES", style: style)
    content.style.shadow = false
    let png = try await frame(content, at: 0.5) { $0.transform.scale = 2 }
    let row = try stride(from: 0.0, through: 1, by: 0.01).map { x in
      try (x, PixelProbe.color(of: png, x: x, y: 0.5).green > 150)
    }
    let lettered = row.filter(\.1).map(\.0)
    let left = try #require(lettered.first)
    let right = try #require(lettered.last)
    #expect(abs((left + right) / 2 - 0.5) < 0.03, "still centred")
    #expect(right - left > 0.6, "twice as wide as the title alone")
  }

  @Test
  func `kinetic words render mid-reveal`() async throws {
    let style = TextStyle(size: 0.14, anchor: .center)
    let png = try await frame(
      TextContent(text: "one two three", style: style, words: words, reveal: .pop),
      at: 0.6,
    )
    #expect(try GoldenFrame.matches(png, named: "words-popping", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// "one" at 0–0.5 s, "two" at 0.5–1 s, "three" at 1–1.5 s.
  private let words = [
    TimedWord(text: "one", start: .zero, end: MediaTime(seconds: 0.5)),
    TimedWord(text: "two", start: MediaTime(seconds: 0.5), end: MediaTime(seconds: 1)),
    TimedWord(text: "three", start: MediaTime(seconds: 1), end: MediaTime(seconds: 1.5)),
  ]

  /// The text over a blue background, rendered at `seconds`.
  private func frame(
    _ content: TextContent,
    at seconds: Double,
    change: (inout Clip) -> Void = { _ in },
  ) async throws -> Data {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 2)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 2),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    var text = Clip(
      source: .text(content),
      sourceStart: .zero,
      duration: MediaTime(seconds: 2),
      timelineStart: .zero,
    )
    change(&text)
    let video = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let project = Project(media: [media], timeline: Timeline(format: .half, tracks: [
      Track(kind: .video, clips: [video]),
      Track(kind: .text, clips: [text]),
    ]))
    return try await FrameRenderer.png(of: project, atSeconds: seconds, maxSide: 480)
  }

}
