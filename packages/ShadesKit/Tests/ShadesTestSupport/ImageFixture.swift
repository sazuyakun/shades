import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes small test pictures, so tests never depend on real images.
public enum ImageFixture {
  /// Writes a PNG of an orange disc on a see-through background (like a cut-out sticker) and
  /// returns its URL.
  public static func makeDisc(width: Int = 400, height: Int = 300) throws(FixtureError) -> URL {
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
      )
    else {
      throw .writerFailed
    }
    context.setFillColor(CGColor(srgbRed: 1, green: 0.55, blue: 0.1, alpha: 1))
    let radius = Double(min(width, height)) * 0.35
    context.fillEllipse(in: CGRect(
      x: Double(width) / 2 - radius,
      y: Double(height) / 2 - radius,
      width: radius * 2,
      height: radius * 2,
    ))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).png")
    guard
      let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil,
      )
    else {
      throw .writerFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw .writerFailed
    }
    return url
  }
}
