import CoreVideo
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
    #expect(try GoldenFrame.matches(png, named: "title-scaled-twice", in: golden))
  }

  @Test
  func `an arched title bends its middle up above its ends`() async throws {
    var style = TextStyle(
      size: 0.12,
      color: HexColor("#FFD84A") ?? .white,
      outline: 0,
      anchor: .center,
    )
    style.shadow = false
    style.arc = 120
    let png = try await frame(TextContent(text: "SHADES SHADES", style: style), at: 0.5)
    /// The highest row with a letter in it, among columns `from` to `to`.
    let top = { (from: Double, to: Double) throws -> Double in
      try stride(from: 0.0, to: 1, by: 0.01).first { y in
        try stride(from: from, through: to, by: 0.01).contains { x in
          try PixelProbe.color(of: png, x: x, y: y).green > 150
        }
      } ?? 1
    }
    let middleTop = try top(0.4, 0.6)
    let sideTop = try top(0.15, 0.25)
    #expect(middleTop < sideTop - 0.05, "the middle sits higher than the side")
    #expect(try GoldenFrame.matches(png, named: "title-arched", in: golden))
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

  @Test
  func `words split into layers draw where they sat in the line`() async throws {
    var content = TextContent(text: "one two three", style: TextStyle(size: 0.12, anchor: .center))
    content.style.shadow = false
    let whole = try await frame(layers: [textClip(content)], at: 0.5)
    let split = try await frame(layers: (0 ..< 3).map { index in
      var word = content
      word.word = index
      return textClip(word)
    }, at: 0.5)
    for x in stride(from: 0.05, through: 0.95, by: 0.03) {
      for y in stride(from: 0.4, through: 0.6, by: 0.02) {
        let expected = try PixelProbe.color(of: whole, x: x, y: y)
        let actual = try PixelProbe.color(of: split, x: x, y: y)
        #expect(abs(Int(expected.green) - Int(actual.green)) < 40, "at \(x), \(y)")
      }
    }
  }

  @Test
  func `each word layer moves and turns about its own centre`() async throws {
    let content = TextContent(text: "one two three", style: TextStyle(size: 0.12, anchor: .center))
    let png = try await frame(layers: (0 ..< 3).map { index in
      var word = content
      word.word = index
      var clip = textClip(word)
      if index == 1 {
        clip.transform = ClipTransform(y: -0.2, rotation: 20)
      }
      if index == 2 {
        clip.transform = ClipTransform(scale: 1.5)
      }
      return clip
    }, at: 0.5)
    #expect(try GoldenFrame.matches(png, named: "words-as-layers", in: golden))
  }

  @Test
  func `text follows a wave, its letters turning with it`() async throws {
    var style = TextStyle(size: 0.1, color: HexColor("#FFD84A") ?? .white, spacing: 0.1)
    style.shadow = false
    let wave = (0 ... 40).map { step in
      let x = Double(step) / 40
      return DrawingPoint(x: 0.05 + x * 0.9, y: 0.5 - 0.15 * sin(x * 2 * .pi))
    }
    let content = TextContent(text: "riding the wave", style: style, path: TextPath(points: wave))
    let png = try await frame(content, at: 0.5)
    #expect(try GoldenFrame.matches(png, named: "text-on-wave", in: golden))
  }

  @Test
  func `keyframing the path offset moves text along its path`() async throws {
    var style = TextStyle(size: 0.1, outline: 0, align: .left)
    style.shadow = false
    let line = TextPath(points: [DrawingPoint(x: 0, y: 0.5), DrawingPoint(x: 1, y: 0.5)])
    let content = TextContent(text: "GO", style: style, path: line)
    let png = try await frame(content, at: 1) { clip in
      clip.keyframes = [
        Keyframe(property: .pathOffset, time: .zero, value: 0),
        Keyframe(property: .pathOffset, time: MediaTime(seconds: 2), value: 1),
      ]
    }
    let lettered = try stride(from: 0.0, through: 1, by: 0.01).filter { x in
      try PixelProbe.color(of: png, x: x, y: 0.46).green > 150
    }
    let left = try #require(lettered.first)
    #expect(abs(left - 0.5) < 0.05, "halfway along at the halfway moment")
  }

  @Test
  func `a distance field measures how far each pixel is inside or outside the ink`() throws {
    var made: CVPixelBuffer?
    CVPixelBufferCreate(nil, 40, 40, kCVPixelFormatType_32BGRA, nil, &made)
    let square = try #require(made)
    CVPixelBufferLockBaseAddress(square, [])
    let bytes = try #require(CVPixelBufferGetBaseAddress(square)?
      .assumingMemoryBound(to: UInt8.self))
    let row = CVPixelBufferGetBytesPerRow(square)
    for y in 0 ..< 40 {
      for x in 0 ..< 40 {
        let isInk = (10 ..< 30).contains(x) && (10 ..< 30).contains(y)
        bytes[y * row + x * 4 + 3] = isInk ? 255 : 0
      }
    }
    CVPixelBufferUnlockBaseAddress(square, [])
    let field = try #require(DistanceField.make(from: square, unit: 1))
    CVPixelBufferLockBaseAddress(field, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(field, .readOnly) }
    let values = try #require(CVPixelBufferGetBaseAddress(field)?
      .assumingMemoryBound(to: UInt8.self))
    let fieldRow = CVPixelBufferGetBytesPerRow(field)
    let value = { (x: Int, y: Int) in Int(values[y * fieldRow + x]) - 128 }
    #expect(value(20, 20) == 10, "the middle is ten pixels in (less the half-pixel edge)")
    #expect(value(10, 20) > 0 && value(8, 20) < 0, "either side of the edge")
    #expect(value(0, 0) == -14, "the corner is ten pixels out on each axis")
  }

  @Test
  func `solid letters turned to the side show their depth`() async throws {
    var style = TextStyle(size: 0.18, color: HexColor("#FFD84A") ?? .white, anchor: .center)
    style.shadow = false
    let flat = TextContent(text: "3D", style: style)
    style.extrusion = TextExtrusion(depth: 0.6, bevel: 0.05)
    let solid = TextContent(text: "3D", style: style)
    let turn = { (clip: inout Clip) in clip.transform = ClipTransform(tiltX: -15, tiltY: 40) }
    /// The leftmost column with ink in the middle row.
    let leftEdge = { (png: Data) throws -> Double in
      try stride(from: 0.3, through: 0.7, by: 0.005).first { x in
        try PixelProbe.color(of: png, x: x, y: 0.5).blue < 120
      } ?? 1
    }
    let flatPNG = try await frame(flat, at: 0.5, change: turn)
    let solidPNG = try await frame(solid, at: 0.5, change: turn)
    #expect(try leftEdge(solidPNG) < leftEdge(flatPNG) - 0.02, "the side shows past the face")
    #expect(try GoldenFrame.matches(solidPNG, named: "title-extruded", in: golden))
  }

  @Test
  func `solid letters bend and blur as they move`() async throws {
    var style = TextStyle(size: 0.16, anchor: .center)
    style.extrusion = TextExtrusion(depth: 0.4, bevel: 0.04)
    let png = try await frame(TextContent(text: "BENT", style: style), at: 1) { clip in
      clip.transform = ClipTransform(tiltX: -20, bend: -120)
      clip.keyframes = [
        Keyframe(property: .x, time: .zero, value: -0.4),
        Keyframe(property: .x, time: MediaTime(seconds: 2), value: 0.4),
      ]
    }
    #expect(try GoldenFrame.matches(png, named: "title-extruded-bent-moving", in: golden))
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
    var text = textClip(content)
    change(&text)
    return try await frame(layers: [text], at: seconds)
  }

  /// A 2-second text clip from the start.
  private func textClip(_ content: TextContent) -> Clip {
    Clip(
      source: .text(content),
      sourceStart: .zero,
      duration: MediaTime(seconds: 2),
      timelineStart: .zero,
    )
  }

  /// Text clips, each on its own track, over a blue background, rendered at `seconds`.
  private func frame(layers: [Clip], at seconds: Double) async throws -> Data {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 2)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 2),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let video = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let project = Project(
      media: [media],
      timeline: Timeline(
        format: .half,
        tracks: [Track(kind: .video, clips: [video])] + layers
          .map { Track(kind: .text, clips: [$0]) },
      ),
    )
    return try await FrameRenderer.png(of: project, atSeconds: seconds, maxSide: 480)
  }

}
