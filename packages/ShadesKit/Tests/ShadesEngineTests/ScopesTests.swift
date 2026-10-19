import CoreGraphics
import ShadesEngine
import Testing

struct ScopesTests {

  // MARK: Internal

  @Test
  func `a mid grey frame reads half bright, colourless, nothing clipped`() throws {
    let reading = try Scopes.measure(solid(red: 128, green: 128, blue: 128)).reading
    #expect(abs(reading.averageBrightness - 0.5) < 0.02)
    #expect(reading.averageSaturation < 0.02)
    #expect(reading.clippedHighlights == 0)
    #expect(reading.crushedShadows == 0)
  }

  @Test
  func `white clips, black crushes, and red is colourful`() throws {
    #expect(try Scopes.measure(solid(red: 255, green: 255, blue: 255)).reading
      .clippedHighlights == 1)
    #expect(try Scopes.measure(solid(red: 0, green: 0, blue: 0)).reading.crushedShadows == 1)
    let red = try Scopes.measure(solid(red: 230, green: 20, blue: 20))
    #expect(red.reading.averageSaturation > 0.5)
    #expect(red.picture.width > 256)
  }

  // MARK: Private

  private func solid(red: UInt8, green: UInt8, blue: UInt8) throws -> CGImage {
    let context = try #require(CGContext(
      data: nil,
      width: 64,
      height: 48,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
    ))
    context.setFillColor(CGColor(
      srgbRed: Double(red) / 255,
      green: Double(green) / 255,
      blue: Double(blue) / 255,
      alpha: 1,
    ))
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
    return try #require(context.makeImage())
  }

}
