import CoreText
import CoreVideo
import Foundation

/// Draws text into transparent frame-sized pictures the compositor layers over the video. The
/// caption look: bold white with a dark outline and soft shadow, centred near the bottom,
/// wrapping within 80% of the width.
enum TextRenderer {

  /// A transparent picture of `size` with `text` drawn as a caption, or `nil` if the GPU memory
  /// for it couldn't be made.
  static func caption(_ text: String, width: Int, height: Int) -> CVPixelBuffer? {
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
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
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
      return nil
    }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    let fontSize = CGFloat(height) * 0.075
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    var alignment = CTTextAlignment.center
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
    let string = NSAttributedString(string: text, attributes: [
      .init(kCTFontAttributeName as String): font,
      .init(kCTForegroundColorAttributeName as String): CGColor(
        red: 1,
        green: 1,
        blue: 1,
        alpha: 1,
      ),
      .init(kCTStrokeColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 0.85),
      .init(kCTStrokeWidthAttributeName as String): -4.0,
      .init(kCTParagraphStyleAttributeName as String): paragraph,
    ])
    let setter = CTFramesetterCreateWithAttributedString(string)
    let boxWidth = CGFloat(width) * 0.8
    let fitted = CTFramesetterSuggestFrameSizeWithConstraints(
      setter,
      CFRange(location: 0, length: 0),
      nil,
      CGSize(width: boxWidth, height: CGFloat(height) * 0.3),
      nil,
    )
    let bottom = CGFloat(height) * 0.1
    let box = CGRect(
      x: (CGFloat(width) - boxWidth) / 2,
      y: bottom,
      width: boxWidth,
      height: ceil(fitted.height),
    )
    context.setShadow(
      offset: CGSize(width: 0, height: -fontSize * 0.06),
      blur: fontSize * 0.25,
      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.6),
    )
    CTFrameDraw(
      CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(
        rect: box,
        transform: nil,
      ), nil),
      context,
    )
    return buffer
  }

}
