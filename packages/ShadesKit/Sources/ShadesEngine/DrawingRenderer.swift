import CoreGraphics
import CoreVideo
import ShadesCore

// MARK: - DrawingRenderer

/// Draws hand-drawn lines onto a transparent frame-sized surface: smoothed through their points,
/// wobbling a little each boil frame, drawn on in stroke order, with an optional glow. The wobble
/// is the same every time for the same moment, so preview and export match.
enum DrawingRenderer {

  // MARK: Internal

  /// Which wobble and how much of the lines show at `time` (seconds into the clip).
  static func moment(of drawing: Drawing, at time: Double) -> DrawingMoment {
    let wobble = drawing.boil > 0 ? Int((time * drawing.boil).rounded(.down)) : 0
    let progress = drawing.writeOn > 0 ? min(max(time / drawing.writeOn, 0), 1) : 1
    // why: steps of a thousandth are finer than a frame and let moments be cached and compared.
    return DrawingMoment(wobble: wobble, drawn: Int((progress * 1000).rounded()))
  }

  /// The drawing at `moment` on a transparent `width`×`height` surface, or `nil` if the surface
  /// couldn't be made.
  static func render(
    _ drawing: Drawing,
    moment: DrawingMoment,
    width: Int,
    height: Int,
  ) -> CVPixelBuffer? {
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
    let size = CGSize(width: width, height: height)
    let lineWidth = max(drawing.width * Double(height), 1)
    let path = visiblePath(of: drawing, moment: moment, size: size, lineWidth: lineWidth)
    let color = CGColor(
      srgbRed: drawing.color.red,
      green: drawing.color.green,
      blue: drawing.color.blue,
      alpha: drawing.color.alpha,
    )
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(lineWidth)
    context.setStrokeColor(color)
    if drawing.glow > 0 {
      context.saveGState()
      context.setShadow(offset: .zero, blur: lineWidth * 6 * drawing.glow, color: color)
      context.addPath(path)
      context.strokePath()
      context.restoreGState()
    }
    context.addPath(path)
    context.strokePath()
    return buffer
  }

  // MARK: Private

  /// The strokes as smooth curves in pixels (CoreGraphics' bottom-left origin), wobbled, and cut
  /// off where the write-on has reached.
  private static func visiblePath(
    of drawing: Drawing,
    moment: DrawingMoment,
    size: CGSize,
    lineWidth: Double,
  ) -> CGPath {
    let wobble = drawing.boil > 0 ? max(lineWidth * 0.4, 0.7) : 0
    let strokes = drawing.strokes.enumerated().map { strokeIndex, stroke in
      stroke.enumerated().map { pointIndex, point in
        CGPoint(
          x: point.x * size.width + wobble * jitter(strokeIndex, pointIndex, moment.wobble, 0),
          y: (1 - point.y) * size.height + wobble * jitter(
            strokeIndex,
            pointIndex,
            moment.wobble,
            1,
          ),
        )
      }
    }
    let lengths = strokes.map(length)
    var budget = lengths.reduce(0, +) * Double(moment.drawn) / 1000
    let path = CGMutablePath()
    for (points, strokeLength) in zip(strokes, lengths) where budget > 0 {
      let shown = strokeLength <= budget ? points : prefix(of: points, length: budget)
      budget -= strokeLength
      addSmoothed(shown, to: path)
    }
    return path
  }

  /// A curve through `points`: straight to the first midpoint, then bending through each point to
  /// the next midpoint, so hand-drawn points don't show corners.
  private static func addSmoothed(_ points: [CGPoint], to path: CGMutablePath) {
    guard let first = points.first else {
      return
    }
    path.move(to: first)
    guard points.count > 2 else {
      for point in points.dropFirst() { path.addLine(to: point) }
      if points.count == 1 {
        path.addLine(to: first)
      }
      return
    }
    for index in 1 ..< points.count - 1 {
      let middle = CGPoint(
        x: (points[index].x + points[index + 1].x) / 2,
        y: (points[index].y + points[index + 1].y) / 2,
      )
      path.addQuadCurve(to: middle, control: points[index])
    }
    if let last = points.last {
      path.addLine(to: last)
    }
  }

  private static func length(_ points: [CGPoint]) -> Double {
    zip(points, points.dropFirst()).reduce(0) { total, pair in
      total + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y)
    }
  }

  /// The start of a stroke up to `length` along it.
  private static func prefix(of points: [CGPoint], length: Double) -> [CGPoint] {
    var result = Array(points.prefix(1))
    var left = length
    for (from, to) in zip(points, points.dropFirst()) {
      let step = hypot(to.x - from.x, to.y - from.y)
      if step >= left {
        let part = step > 0 ? left / step : 0
        result.append(CGPoint(
          x: from.x + (to.x - from.x) * part,
          y: from.y + (to.y - from.y) * part,
        ))
        return result
      }
      result.append(to)
      left -= step
    }
    return result
  }

  /// A steady pseudo-random value from -1 to 1 for one point, wobble and axis.
  private static func jitter(_ stroke: Int, _ point: Int, _ wobble: Int, _ axis: Int) -> Double {
    var value = UInt64(truncatingIfNeeded: stroke &* 73_856_093 ^ point &* 19_349_663
      ^ wobble &* 83_492_791 ^ axis &* 2_654_435_761)
    // why: a few rounds of SplitMix64 mixing turn neighbouring inputs into unrelated outputs.
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    value ^= value >> 31
    return Double(value % 2001) / 1000 - 1
  }

}

// MARK: - DrawingMoment

/// Which wobble a drawing shows, and how much of it is drawn on (in thousandths).
struct DrawingMoment: Hashable {
  let wobble: Int
  let drawn: Int
}
