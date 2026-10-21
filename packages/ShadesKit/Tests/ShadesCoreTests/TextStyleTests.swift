import Foundation
import ShadesCore
import Testing

struct TextStyleTests {
  @Test
  func `colours read from hex with or without alpha and write back`() throws {
    let solid = try #require(HexColor("#FF8000"))
    #expect(solid.red == 1)
    #expect(abs(solid.green - 128.0 / 255) < 0.0001)
    #expect(solid.alpha == 1)
    #expect(solid.hex == "#FF8000")
    let clear = try #require(HexColor("00000080"))
    #expect(abs(clear.alpha - 128.0 / 255) < 0.0001)
    #expect(clear.hex == "#00000080")
    #expect(HexColor("orange") == nil)
    #expect(HexColor("#FFF") == nil)
  }

  @Test
  func `a partial style keeps the caption look for what it leaves out`() throws {
    let json = Data(##"{"size": 0.2, "color": "#FFD84A", "anchor": "center"}"##.utf8)
    let style = try JSONDecoder().decode(TextStyle.self, from: json)
    #expect(style.size == 0.2)
    #expect(style.color == HexColor("#FFD84A"))
    #expect(style.anchor == .center)
    #expect(style.outline == TextStyle.caption.outline)
    #expect(style.shadow)
  }

  @Test
  func `text saved before styles existed loads with the caption look`() throws {
    let json = Data(#"{"text": "hello"}"#.utf8)
    let content = try JSONDecoder().decode(TextContent.self, from: json)
    #expect(content.style == .caption)
    #expect(content.reveal == .none)
    #expect(content.words == nil)
    #expect(content.path == nil && content.word == nil && content.style.spacing == 0)
  }

  @Test
  func `text on a path round-trips and its offset is a keyframeable value`() throws {
    let content = TextContent(
      text: "round and round",
      style: TextStyle(spacing: 0.2),
      word: 1,
      path: TextPath(points: [DrawingPoint(x: 0, y: 0.5), DrawingPoint(x: 1, y: 0.5)], offset: 0.3),
    )
    let data = try JSONEncoder().encode(content)
    #expect(try JSONDecoder().decode(TextContent.self, from: data) == content)
    #expect(content.shownText == "and")
    let clip = Clip(
      source: .text(content),
      sourceStart: .zero,
      duration: MediaTime(seconds: 2),
      timelineStart: .zero,
    )
    #expect(clip.value(of: .pathOffset, at: .zero) == 0.3)
  }

  @Test
  func `styled kinetic text round-trips`() throws {
    let content = TextContent(
      text: "chul ka keeda",
      style: TextStyle(font: "Futura-Bold", size: 0.12, align: .left, anchor: .center),
      words: [TimedWord(text: "chul", start: .zero, end: MediaTime(seconds: 0.4))],
      reveal: .pop,
    )
    let data = try JSONEncoder().encode(content)
    #expect(try JSONDecoder().decode(TextContent.self, from: data) == content)
  }
}
