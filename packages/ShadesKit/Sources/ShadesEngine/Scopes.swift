import CoreGraphics
import Foundation

// MARK: - Scopes

/// Measures a frame the way a colourist reads it: a waveform (brightness across the picture), a
/// vectorscope (hue and saturation), an RGB histogram, and the numbers behind them.
public enum Scopes {

  // MARK: Public

  /// The scopes of `image` as one picture (waveform and vectorscope over the histogram), and
  /// their numbers.
  public static func measure(_ image: CGImage) throws(EngineError)
    -> (picture: CGImage, reading: ScopeReading)
  {
    let sample = try rgba(of: image, maxWidth: 360)
    let pixels = sample.pixels
    let width = sample.width
    var waveform = [UInt32](repeating: 0, count: width * 256)
    var vector = [UInt32](repeating: 0, count: 256 * 256)
    var histogram = [[UInt32]](repeating: [UInt32](repeating: 0, count: 256), count: 3)
    var lumaTotal = 0.0
    var saturationTotal = 0.0
    var clipped = 0
    var crushed = 0
    for (index, pixel) in pixels.enumerated() {
      let red = Double(pixel.0)
      let green = Double(pixel.1)
      let blue = Double(pixel.2)
      let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
      let level = min(Int(luma), 255)
      waveform[(255 - level) * width + index % width] += 1
      let cb: Double = -0.1146 * red - 0.3854 * green + 0.5 * blue
      let cr = 0.5 * red - 0.4542 * green - 0.0458 * blue
      let vectorRow = min(max(Int(128 - cr), 0), 255)
      let vectorColumn = min(max(Int(128 + cb), 0), 255)
      vector[vectorRow * 256 + vectorColumn] += 1
      histogram[0][Int(pixel.0)] += 1
      histogram[1][Int(pixel.1)] += 1
      histogram[2][Int(pixel.2)] += 1
      lumaTotal += luma
      let chroma: Double = (cb * cb + cr * cr).squareRoot()
      saturationTotal += chroma / 128
      clipped += level >= 250 ? 1 : 0
      crushed += level <= 5 ? 1 : 0
    }
    let count = Double(max(pixels.count, 1))
    let reading = ScopeReading(
      averageBrightness: lumaTotal / count / 255,
      clippedHighlights: Double(clipped) / count,
      crushedShadows: Double(crushed) / count,
      averageSaturation: saturationTotal / count,
    )
    return (
      try drawScopes(waveform: waveform, width: width, vector: vector, histogram: histogram),
      reading,
    )
  }

  // MARK: Private

  /// The image's pixels (8-bit RGB), scaled to at most `maxWidth` across, row by row, and how
  /// wide a row is.
  private static func rgba(
    of image: CGImage,
    maxWidth: Int,
  ) throws(EngineError) -> (pixels: [(UInt8, UInt8, UInt8)], width: Int) {
    let scale = min(1, Double(maxWidth) / Double(image.width))
    let width = max(Int(Double(image.width) * scale), 1)
    let height = max(Int(Double(image.height) * scale), 1)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width * 4,
          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
        )
      else {
        return false
      }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else {
      logger.error("scopes.failed reason=draw")
      throw .renderFailed
    }
    let pixels = stride(from: 0, to: bytes.count, by: 4).map { (
      bytes[$0],
      bytes[$0 + 1],
      bytes[$0 + 2],
    ) }
    return (pixels, width)
  }

  /// Waveform (left) and vectorscope (right) on top, the RGB histogram underneath, as glowing
  /// green and coloured traces on black.
  private static func drawScopes(
    waveform: [UInt32],
    width: Int,
    vector: [UInt32],
    histogram: [[UInt32]],
  ) throws(EngineError) -> CGImage {
    let total = width + 16 + 256
    let height = 256 + 16 + 120
    var bytes = [UInt8](repeating: 0, count: total * height * 4)
    func plot(_ x: Int, _ y: Int, _ color: (Double, Double, Double), _ strength: Double) {
      let offset = (y * total + x) * 4
      for (channel, value) in [color.0, color.1, color.2].enumerated() {
        bytes[offset + channel] = UInt8(min(
          255,
          Double(bytes[offset + channel]) + value * strength * 255,
        ))
      }
      bytes[offset + 3] = 255
    }
    let waveMax = Double(waveform.max() ?? 1)
    for row in 0 ..< 256 {
      for column in 0 ..< width where waveform[row * width + column] > 0 {
        plot(
          column,
          row,
          (0.3, 1, 0.4),
          0.25 + 0.75 * Double(waveform[row * width + column]) / waveMax,
        )
      }
    }
    let vectorMax = Double(vector.max() ?? 1)
    for row in 0 ..< 256 {
      for column in 0 ..< 256 where vector[row * 256 + column] > 0 {
        let strength = 0.3 + 0.7 * (Double(vector[row * 256 + column]) / vectorMax).squareRoot()
        plot(width + 16 + column, row, (0.3, 1, 0.4), strength)
      }
    }
    for step in 0 ..< 256 {
      let angle = Double(step) / 256 * 2 * .pi
      plot(
        width + 16 + 128 + Int(127 * cos(angle)),
        128 + Int(127 * sin(angle)),
        (0.3, 0.3, 0.3),
        1,
      )
    }
    let histogramMax = Double(histogram.flatMap(\.self).max() ?? 1)
    let colors = [(1.0, 0.25, 0.25), (0.25, 1.0, 0.25), (0.3, 0.45, 1.0)]
    for (channel, counts) in histogram.enumerated() {
      for level in 0 ..< 256 {
        let bar = Int(Double(counts[level]) / histogramMax * 119)
        let x = level * (total - 1) / 255
        for rise in 0 ..< bar {
          plot(x, height - 1 - rise, colors[channel], 0.45)
        }
      }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)
    guard
      let provider,
      let picture = CGImage(
        width: total,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: total * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent,
      )
    else {
      logger.error("scopes.failed reason=image")
      throw .renderFailed
    }
    return picture
  }

}

// MARK: - ScopeReading

/// A frame's exposure and colour in numbers, each 0 to 1.
public struct ScopeReading: Sendable {
  /// Mean brightness: about 0.4–0.5 is a normally exposed picture.
  public let averageBrightness: Double
  /// Share of the picture that's blown-out white.
  public let clippedHighlights: Double
  /// Share of the picture that's crushed black.
  public let crushedShadows: Double
  /// Mean colourfulness: near 0 is black and white.
  public let averageSaturation: Double
}
