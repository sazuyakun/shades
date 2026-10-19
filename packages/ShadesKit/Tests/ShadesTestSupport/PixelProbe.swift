import CoreGraphics
import Foundation
import ImageIO

/// Reads single pixels of rendered frames, for checks like "the middle is red".
public enum PixelProbe {
  /// The colour of the PNG at (`x`, `y`), as fractions of its size from the top left.
  public static func color(
    of png: Data,
    x: Double,
    y: Double,
  ) throws(FixtureError) -> (red: UInt8, green: UInt8, blue: UInt8) {
    var pixel = [UInt8](repeating: 0, count: 4)
    guard
      let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
      )
    else {
      throw .imageUnreadable
    }
    let width = Double(image.width)
    let height = Double(image.height)
    // why: CoreGraphics' origin is bottom-left, so the row is counted up from the bottom.
    context.draw(
      image,
      in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height),
    )
    return (pixel[0], pixel[1], pixel[2])
  }
}
