import CoreText
import CoreVideo
import Foundation
import ShadesCore

// MARK: - TextRenderer

/// Draws a text clip into a transparent picture just big enough for it, at the frame's pixel
/// scale, with its words revealed as they should be at a moment (kinetic type).
enum TextRenderer {

  // MARK: Internal

  /// How each word looks at `time` (seconds into the clip's source): whether and how far it's
  /// in, and whether it's the one being said. Also a key that changes only when the drawing does.
  static func wordStates(
    of content: TextContent,
    at time: Double,
    duration: Double,
  ) -> (states: [WordState], key: String) {
    let words = content.text.split(separator: " ", omittingEmptySubsequences: true)
    let timings = timings(of: content, count: words.count, duration: duration)
    let states = words.indices.map { index -> WordState in
      let (start, end) = timings[index]
      switch content.reveal {
      case .none:
        return WordState(scale: 1, alpha: 1, isSaid: false, letters: nil)

      case .pop:
        let age = time - start
        guard age >= 0 else {
          return WordState(scale: 1, alpha: 0, isSaid: false, letters: nil)
        }
        let grown = Easing.bouncy.progress(min(age / popLength, 1))
        return WordState(
          scale: 0.4 + 0.6 * grown,
          alpha: min(age / (popLength / 3), 1),
          isSaid: false,
          letters: nil,
        )

      case .highlight:
        return WordState(scale: 1, alpha: 1, isSaid: start <= time && time < end, letters: nil)

      case .typewriter:
        let letters = Double(words[index].count)
        let typed = ((time - start) / max(end - start, 0.01) * letters).rounded(.down)
        let shown = Int(min(max(typed, 0), letters))
        return WordState(scale: 1, alpha: shown > 0 ? 1 : 0, isSaid: false, letters: shown)
      }
    }
    let key = states.lazy.map { state in
      // why: frame-sized steps of the pop are enough; finer steps would never be reused.
      "\(Int(state.scale * 60))/\(Int(state.alpha * 60))/\(state.isSaid)/\(state.letters ?? -1)"
    }.joined(separator: ",")
    return (states, key)
  }

  /// The text drawn on a transparent surface, and where its centre sits in the frame (offset from
  /// the frame's centre as fractions of its size), or `nil` if drawing failed.
  static func render(
    _ content: TextContent,
    states: [WordState],
    frameWidth: Int,
    frameHeight: Int,
  ) -> (buffer: CVPixelBuffer, offset: CGPoint)? {
    let style = content.style
    let fontSize = CGFloat(frameHeight) * style.size
    let fill = attributedText(content, states: states, fontSize: fontSize, isOutline: false)
    let setter = CTFramesetterCreateWithAttributedString(fill)
    let maxWidth = CGFloat(frameWidth) * 0.8
    let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
      setter,
      CFRange(location: 0, length: 0),
      nil,
      CGSize(width: maxWidth, height: CGFloat(frameHeight)),
      nil,
    )
    let margin = ceil(fontSize * 0.5)
    let textBox = CGSize(width: ceil(fitted.width) + 2, height: ceil(fitted.height))
    let width = Int(textBox.width + margin * 2)
    let height = Int(textBox.height + margin * 2)
    guard let (buffer, context) = surface(width: width, height: height) else {
      return nil
    }
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let path = CGPath(
      rect: CGRect(origin: CGPoint(x: margin, y: margin), size: textBox),
      transform: nil,
    )
    let everything = CFRange(location: 0, length: 0)
    if style.shadow {
      context.setShadow(
        offset: CGSize(width: 0, height: -fontSize * 0.06),
        blur: fontSize * 0.25,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6),
      )
    }
    // why: system fonts build letters from overlapping shapes; outlining them in the same pass as
    // the fill shows the overlaps, so the outline is drawn first and the fill covers it.
    if style.outline > 0 {
      let outline = attributedText(content, states: states, fontSize: fontSize, isOutline: true)
      context.setLineJoin(.round)
      draw(
        CTFramesetterCreateFrame(
          CTFramesetterCreateWithAttributedString(outline),
          everything,
          path,
          nil,
        ),
        states: states,
        in: context,
      )
      context.setShadow(offset: .zero, blur: 0, color: nil)
    }
    draw(CTFramesetterCreateFrame(setter, everything, path, nil), states: states, in: context)
    let centerY = style.anchor == .bottom
      ? CGFloat(frameHeight) * 0.9 - textBox.height / 2
      : CGFloat(frameHeight) / 2
    return (buffer, CGPoint(x: 0, y: centerY / CGFloat(frameHeight) - 0.5))
  }

  // MARK: Private

  /// How long a word takes to pop in, in seconds.
  private static let popLength = 0.25

  /// Marks which word a stretch of text belongs to, so each can be drawn on its own.
  private static let wordKey = NSAttributedString.Key("ShadesWord")

  /// Each word's start and end: from the transcript when it matches the text, otherwise spread
  /// over the start of the clip.
  private static func timings(
    of content: TextContent,
    count: Int,
    duration: Double,
  ) -> [(Double, Double)] {
    if let words = content.words, words.count == count {
      return words.map { ($0.start.seconds, $0.end.seconds) }
    }
    let step = min(0.3, duration / Double(max(count, 1)))
    return (0 ..< count).map { (Double($0) * step, Double($0 + 1) * step) }
  }

  /// The text's fill (or its outline only) with each word marked by its index, coloured by its
  /// state, and letters not yet typed made clear: they still take their space, so nothing
  /// shifts as they appear.
  private static func attributedText(
    _ content: TextContent,
    states: [WordState],
    fontSize: CGFloat,
    isOutline: Bool,
  ) -> NSAttributedString {
    let style = content.style
    let font = style.font.map { CTFontCreateWithName($0 as CFString, fontSize, nil) }
      ?? CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let highlight = style.highlight ?? HexColor("#FFD84A") ?? .white
    let string = NSMutableAttributedString()
    let words = content.text.split(separator: " ", omittingEmptySubsequences: true)
    for (index, word) in words.enumerated() {
      let state = states.indices.contains(index)
        ? states[index]
        : WordState(scale: 1, alpha: 1, isSaid: false, letters: nil)
      let color = cgColor(state.isSaid ? highlight : style.color)
      let shown = min(state.letters ?? word.count, word.count)
      let text = String(word)
      var attributes: [NSAttributedString.Key: Any] = [
        .init(kCTFontAttributeName as String): font,
        wordKey: index,
      ]
      // why: a stroke is centred on the letter's edge, so twice the width shows the asked
      // thickness outside the fill.
      if isOutline {
        attributes[.init(kCTStrokeWidthAttributeName as String)] = style.outline * 200
      }
      let paint = isOutline ? kCTStrokeColorAttributeName : kCTForegroundColorAttributeName
      var shownAttributes = attributes
      shownAttributes[.init(paint as String)] = isOutline ? cgColor(style.outlineColor) : color
      var hiddenAttributes = attributes
      hiddenAttributes[.init(paint as String)] = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)
      string.append(NSAttributedString(
        string: String(text.prefix(shown)),
        attributes: shownAttributes,
      ))
      string.append(NSAttributedString(
        string: String(text.dropFirst(shown)),
        attributes: hiddenAttributes,
      ))
      if index < words.count - 1 {
        string.append(NSAttributedString(string: " ", attributes: attributes))
      }
    }
    var alignment =
      switch style.align {
      case .left: CTTextAlignment.left
      case .center: CTTextAlignment.center
      case .right: CTTextAlignment.right
      }
    let paragraph = withUnsafeBytes(of: &alignment) { pointer -> CTParagraphStyle in
      guard let base = pointer.baseAddress else {
        return CTParagraphStyleCreate(nil, 0)
      }
      var setting = CTParagraphStyleSetting(
        spec: .alignment,
        valueSize: MemoryLayout<CTTextAlignment>.size,
        value: base,
      )
      return CTParagraphStyleCreate(&setting, 1)
    }
    string.addAttribute(
      .init(kCTParagraphStyleAttributeName as String),
      value: paragraph,
      range: NSRange(location: 0, length: string.length),
    )
    return string
  }

  /// Draws the laid-out text word by word, each scaled about its own centre and faded by its
  /// state.
  private static func draw(_ frame: CTFrame, states: [WordState], in context: CGContext) {
    let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
    let frameOrigin = CTFrameGetPath(frame).boundingBox.origin
    for (line, origin) in zip(lines, origins) {
      let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
      for run in runs {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        let index = attributes[wordKey] as? Int ?? -1
        let state = states.indices.contains(index)
          ? states[index]
          : WordState(scale: 1, alpha: 1, isSaid: false, letters: nil)
        guard state.alpha > 0 else {
          continue
        }
        let bounds = CTRunGetImageBounds(run, context, CFRange(location: 0, length: 0))
        let lineOrigin = CGPoint(x: frameOrigin.x + origin.x, y: frameOrigin.y + origin.y)
        let center = CGPoint(x: lineOrigin.x + bounds.midX, y: lineOrigin.y + bounds.midY)
        context.saveGState()
        context.setAlpha(state.alpha)
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: state.scale, y: state.scale)
        context.translateBy(x: -center.x, y: -center.y)
        context.textPosition = lineOrigin
        CTRunDraw(run, context, CFRange(location: 0, length: 0))
        context.restoreGState()
      }
    }
  }

  /// A transparent BGRA surface the GPU can read, locked and ready to draw into.
  private static func surface(width: Int, height: Int) -> (CVPixelBuffer, CGContext)? {
    var made: CVPixelBuffer?
    let attributes: [String: Any] = [
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
      kCVPixelBufferMetalCompatibilityKey as String: true,
    ]
    CVPixelBufferCreate(
      nil,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes as CFDictionary,
      &made,
    )
    guard let buffer = made else {
      return nil
    }
    CVPixelBufferLockBaseAddress(buffer, [])
    guard
      let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little
          .rawValue,
      )
    else {
      CVPixelBufferUnlockBaseAddress(buffer, [])
      return nil
    }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    return (buffer, context)
  }

  private static func cgColor(_ color: HexColor) -> CGColor {
    CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
  }

}

// MARK: - WordState

/// How one word is drawn at a moment.
struct WordState {
  let scale: Double
  let alpha: Double
  /// Whether it's the word being said (drawn in the highlight colour).
  let isSaid: Bool
  /// How many letters are typed so far, for the typewriter reveal.
  let letters: Int?
}
