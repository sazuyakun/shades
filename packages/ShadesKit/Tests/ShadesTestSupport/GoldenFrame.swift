import CoreGraphics
import Foundation
import ImageIO

// MARK: - GoldenFrame

/// Compares rendered frames with reference PNGs checked into the repo, so any visual change is
/// caught. Run tests with `SHADES_RECORD_GOLDEN=1` to (re)record references after an approved
/// change.
public enum GoldenFrame {

  // MARK: Public

  /// Whether `png` looks the same as the reference `<name>.png` in `directory`. A missing
  /// reference is recorded and reported as a mismatch, so CI never passes without one. On a
  /// mismatch the actual frame is written next to the reference as `<name>.actual.png`.
  public static func matches(
    _ png: Data,
    named name: String,
    in directory: URL,
  ) throws(FixtureError) -> Bool {
    let reference = directory.appending(path: "\(name).png")
    let isRecording = ProcessInfo.processInfo.environment["SHADES_RECORD_GOLDEN"] == "1"
    // why: an unreadable reference means there is none yet, which records it.
    guard !isRecording, let expected = try? Data(contentsOf: reference) else {
      try write(png, to: reference)
      return isRecording
    }
    let isSame = try isClose(rgba(of: png), rgba(of: expected))
    if !isSame {
      try write(png, to: directory.appending(path: "\(name).actual.png"))
    }
    return isSame
  }

  // MARK: Private

  /// A channel may drift this much (out of 255) between machines' video decoders.
  private static let channelTolerance = 12
  /// Fraction of pixels allowed to differ even after the one-pixel allowance.
  private static let outlierFraction = 0.005

  /// Pixels match if the expected pixel, or one of its neighbours, is within tolerance, so an
  /// edge that a GPU anti-aliases a fraction of a pixel differently still passes.
  private static func isClose(_ actual: Bitmap, _ expected: Bitmap) -> Bool {
    guard actual.width == expected.width, actual.height == expected.height else {
      return false
    }
    var outliers = 0
    for y in 0 ..< actual.height {
      for x in 0 ..< actual.width where !hasNearbyMatch(x, y, actual, expected) {
        outliers += 1
      }
    }
    return Double(outliers) <= Double(actual.width * actual.height) * outlierFraction
  }

  private static func hasNearbyMatch(_ x: Int, _ y: Int, _ actual: Bitmap, _ expected: Bitmap)
    -> Bool
  {
    let pixel = (y * actual.width + x) * 4
    for neighbourY in max(y - 1, 0) ... min(y + 1, actual.height - 1) {
      for neighbourX in max(x - 1, 0) ... min(x + 1, actual.width - 1) {
        let other = (neighbourY * actual.width + neighbourX) * 4
        let isSame = (0 ..< 4).allSatisfy { channel in
          abs(Int(actual.bytes[pixel + channel]) - Int(expected.bytes[other + channel]))
            <= channelTolerance
        }
        if isSame {
          return true
        }
      }
    }
    return false
  }

  private static func rgba(of png: Data) throws(FixtureError) -> Bitmap {
    guard
      let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      throw .imageUnreadable
    }
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer in
      let context = CGContext(
        data: buffer.baseAddress,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
      )
      context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
      return context != nil
    }
    guard drawn else {
      throw .imageUnreadable
    }
    return Bitmap(width: image.width, height: image.height, bytes: bytes)
  }

  private static func write(_ png: Data, to url: URL) throws(FixtureError) {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      try png.write(to: url)
    } catch {
      throw .writerFailed
    }
  }

}

// MARK: - Bitmap

/// Decoded RGBA pixels.
private struct Bitmap {
  let width: Int
  let height: Int
  let bytes: [UInt8]
}
