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
  /// A per-word layer hides every word but its own.
  static func wordStates(
    of content: TextContent,
    at time: Double,
    duration: Double,
  ) -> (states: [WordState], key: String) {
    let words = content.wordList
    let timings = timings(of: content, count: words.count, duration: duration)
    let states = words.indices.map { index -> WordState in
      let (start, end) = timings[index]
      if let word = content.word, word != index {
        return WordState(scale: 1, alpha: 0, isSaid: false, letters: nil)
      }
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
  /// the frame's centre as fractions of its size), or `nil` if drawing failed. A per-word layer
  /// is cropped to its word, centred where the word sits in the whole text.
  static func render(
    _ content: TextContent,
    states: [WordState],
    frameWidth: Int,
    frameHeight: Int,
  ) -> (buffer: CVPixelBuffer, offset: CGPoint)? {
    let style = content.style
    let frame = CGSize(width: frameWidth, height: frameHeight)
    let fontSize = frame.height * style.size
    let fill = attributedText(content, states: states, fontSize: fontSize, isOutline: false)
    let layout = layout(of: fill, content: content, states: states, frame: frame)
    let outline = style.outline > 0
      ? self.layout(
        of: attributedText(content, states: states, fontSize: fontSize, isOutline: true),
        content: content,
        states: states,
        frame: frame,
      ).pieces
      : []
    let shown = layout.pieces.filter { $0.alpha > 0 }.map(\.bounds)
    let box = content.word == nil
      ? layout.box
      : shown.reduce(shown.first ?? .zero) { $0.union($1) }.integral
    // why: solid letters cast no flat shadow, so they need room only for their outline.
    let margin = style.extrusion == nil ? ceil(fontSize * 0.5) : ceil(fontSize * style.outline) + 4
    guard
      let (buffer, context) = surface(
        width: Int(box.width + margin * 2),
        height: Int(box.height + margin * 2),
      )
    else {
      return nil
    }
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    context.translateBy(x: margin - box.minX, y: margin - box.minY)
    if style.shadow, style.extrusion == nil {
      context.setShadow(
        offset: CGSize(width: 0, height: -fontSize * 0.06),
        blur: fontSize * 0.25,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.6),
      )
    }
    // why: one layer casts one shadow, so letters' shadows don't darken where they overlap.
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    // why: system fonts build letters from overlapping shapes; outlining them in the same pass as
    // the fill shows the overlaps, so the outline is drawn first and the fill covers it.
    context.setLineJoin(.round)
    draw(outline, in: context)
    draw(layout.pieces, in: context)
    context.endTransparencyLayer()
    let offset = CGPoint(
      x: layout.anchorOffset.x + (box.midX - layout.anchor.x) / frame.width,
      y: layout.anchorOffset.y - (box.midY - layout.anchor.y) / frame.height,
    )
    return (buffer, offset)
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
    let words = content.wordList
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
      // why: any kern value, even 0, replaces the font's own pair kerning.
      if style.spacing != 0 {
        attributes[.init(kCTKernAttributeName as String)] = style.spacing * fontSize
      }
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

  /// Where every stretch of the text goes: in lines wrapped to the frame, or letter by letter
  /// along its path or arc.
  private static func layout(
    of string: NSAttributedString,
    content: TextContent,
    states: [WordState],
    frame: CGSize,
  ) -> TextLayout {
    let style = content.style
    if let path = content.path {
      let line = CTLineCreateWithAttributedString(string)
      let width = CTLineGetTypographicBounds(line, nil, nil, nil)
      // why: the path is in the frame (y down); drawing space has y up.
      let along = Polyline(path.points.map { point in
        CGPoint(x: point.x * frame.width, y: (1 - point.y) * frame.height)
      })
      let room = along.length - CGFloat(width)
      let aligned: CGFloat =
        switch style.align {
        case .left: 0
        case .center: room / 2
        case .right: room
        }
      let pieces = glyphs(
        of: line,
        along: along,
        from: aligned + along.length * path.offset,
        states: states,
      )
      return TextLayout(
        pieces: pieces,
        box: pieces.map(\.bounds).reduce(pieces.first?.bounds ?? .zero) { $0.union($1) }.integral,
        anchor: CGPoint(x: frame.width / 2, y: frame.height / 2),
        anchorOffset: .zero,
      )
    }
    if style.arc != 0 {
      let line = CTLineCreateWithAttributedString(string)
      let width = CTLineGetTypographicBounds(line, nil, nil, nil)
      let pieces = glyphs(of: line, along: arc(width: width, degrees: style.arc), states: states)
      let box = pieces.map(\.bounds).reduce(pieces.first?.bounds ?? .zero) { $0.union($1) }
        .integral
      return TextLayout(
        pieces: pieces,
        box: box,
        anchor: CGPoint(x: box.midX, y: box.midY),
        anchorOffset: anchorOffset(style, height: box.height, frame: frame),
      )
    }
    return lines(of: string, style: style, states: states, frame: frame)
  }

  /// The text wrapped into lines at most 80% of the frame wide, each word drawn whole, scaled
  /// about its own centre.
  private static func lines(
    of string: NSAttributedString,
    style: TextStyle,
    states: [WordState],
    frame: CGSize,
  ) -> TextLayout {
    let setter = CTFramesetterCreateWithAttributedString(string)
    let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
      setter,
      CFRange(location: 0, length: 0),
      nil,
      CGSize(width: frame.width * 0.8, height: frame.height),
      nil,
    )
    let box = CGRect(x: 0, y: 0, width: ceil(fitted.width) + 2, height: ceil(fitted.height))
    let textFrame = CTFramesetterCreateFrame(
      setter,
      CFRange(location: 0, length: 0),
      CGPath(rect: box, transform: nil),
      nil,
    )
    let lines = CTFrameGetLines(textFrame) as? [CTLine] ?? []
    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(textFrame, CFRange(location: 0, length: 0), &origins)
    let pieces = zip(lines, origins).flatMap { line, origin in
      (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).map { run in
        let state = state(of: run, in: states)
        let everything = CFRange(location: 0, length: 0)
        let bounds = CTRunGetImageBounds(run, nil, everything)
        let center = CGPoint(x: origin.x + bounds.midX, y: origin.y + bounds.midY)
        let scaling = CGAffineTransform(translationX: -center.x, y: -center.y)
          .concatenating(CGAffineTransform(scaleX: state.scale, y: state.scale))
          .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        let placement = CGAffineTransform(translationX: origin.x, y: origin.y)
          .concatenating(scaling)
        return TextPiece(
          run: run,
          range: everything,
          placement: placement,
          bounds: bounds.applying(placement),
          alpha: state.alpha,
        )
      }
    }
    return TextLayout(
      pieces: pieces,
      box: box,
      anchor: CGPoint(x: box.midX, y: box.midY),
      anchorOffset: anchorOffset(style, height: box.height, frame: frame),
    )
  }

  /// Each letter of `line` stood on `path` (its baseline along it, turned to follow it) from
  /// `start` along the path, scaled about its own centre by its word's state. Letters past the
  /// ends of an open path aren't drawn.
  private static func glyphs(
    of line: CTLine,
    along path: Polyline,
    from start: CGFloat = 0,
    states: [WordState],
  ) -> [TextPiece] {
    (CTLineGetGlyphRuns(line) as? [CTRun] ?? []).flatMap { run -> [TextPiece] in
      let state = state(of: run, in: states)
      let count = CTRunGetGlyphCount(run)
      var positions = [CGPoint](repeating: .zero, count: count)
      var advances = [CGSize](repeating: .zero, count: count)
      CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
      CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
      return (0 ..< count).compactMap { index in
        let middle = positions[index].x + advances[index].width / 2
        guard let (point, angle) = path.locate(start + middle) else {
          return nil
        }
        let placement = CGAffineTransform(translationX: -middle, y: 0)
          .concatenating(CGAffineTransform(scaleX: state.scale, y: state.scale))
          .concatenating(CGAffineTransform(rotationAngle: angle))
          .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
        let range = CFRange(location: index, length: 1)
        return TextPiece(
          run: run,
          range: range,
          placement: placement,
          bounds: CTRunGetImageBounds(run, nil, range).applying(placement),
          alpha: state.alpha,
        )
      }
    }
  }

  /// A circular arc `width` long, bent by `degrees`: positive arches up like a rainbow, negative
  /// dips like a smile.
  private static func arc(width: CGFloat, degrees: Double) -> Polyline {
    let sweep = abs(degrees) * .pi / 180
    let radius = width / sweep
    let bulge: CGFloat = degrees > 0 ? 1 : -1
    return Polyline((0 ... 128).map { step in
      let angle = (Double(step) / 128 - 0.5) * sweep
      return CGPoint(x: radius * sin(angle), y: bulge * radius * (cos(angle) - 1))
    })
  }

  /// Where the middle of text `height` tall sits, from the frame's centre as fractions: near the
  /// bottom like a caption, or in the middle.
  private static func anchorOffset(_ style: TextStyle, height: CGFloat, frame: CGSize) -> CGPoint {
    let centerY = style.anchor == .bottom ? frame.height * 0.9 - height / 2 : frame.height / 2
    return CGPoint(x: 0, y: centerY / frame.height - 0.5)
  }

  private static func state(of run: CTRun, in states: [WordState]) -> WordState {
    let attributes = CTRunGetAttributes(run) as NSDictionary
    let index = attributes[wordKey] as? Int ?? -1
    return states.indices.contains(index)
      ? states[index]
      : WordState(scale: 1, alpha: 1, isSaid: false, letters: nil)
  }

  /// Draws each visible piece where it goes, faded by its word's state.
  private static func draw(_ pieces: [TextPiece], in context: CGContext) {
    for piece in pieces where piece.alpha > 0 {
      context.saveGState()
      context.setAlpha(piece.alpha)
      context.concatenate(piece.placement)
      context.textPosition = .zero
      CTRunDraw(piece.run, context, piece.range)
      context.restoreGState()
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

// MARK: - TextLayout

/// Where every stretch of a text goes, in drawing space (y up), and how that space sits in the
/// frame.
private struct TextLayout {
  let pieces: [TextPiece]
  /// The whole text's box.
  let box: CGRect
  /// A point of the drawing space…
  let anchor: CGPoint
  /// …and where it sits in the frame, from its centre as fractions (y down).
  let anchorOffset: CGPoint
}

// MARK: - TextPiece

/// Glyphs of one run drawn together: a whole word in lines, a single letter along a path.
private struct TextPiece {
  let run: CTRun
  let range: CFRange
  /// Takes the run's own drawing space to the layout's.
  let placement: CGAffineTransform
  /// Where its ink lands in the layout.
  let bounds: CGRect
  let alpha: Double
}
