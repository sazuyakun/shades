import CoreGraphics
import CoreText
import Foundation

/// A stretch of the edit on one picture, for Claude to check motion and sound: frames in a
/// grid, each labelled with its time, over the sound's waveform with a tick at every frame.
public enum PreviewSheet {

  // MARK: Public

  /// The sheet of `frames` (shown at `times`, in seconds), with the waveform of `sound`
  /// (interleaved stereo samples covering `times.first` to `end`) when there is some.
  public static func image(
    frames: [CGImage],
    times: [Double],
    sound: [Float]?,
    end: Double,
  ) throws(EngineError) -> CGImage {
    guard let first = frames.first, let start = times.first else {
      logger.error("preview.failed reason=noFrames")
      throw .renderFailed
    }
    let columns = min(frames.count, maxColumns)
    let rows = (frames.count + columns - 1) / columns
    let cell = CGSize(width: first.width, height: first.height)
    let width = Int(cell.width) * columns
    let waveHeight = sound == nil ? 0 : Self.waveHeight
    let height = Int(cell.height) * rows + waveHeight
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue,
      )
    else {
      logger.error("preview.failed reason=context")
      throw .renderFailed
    }
    context.setFillColor(gray: 0, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    for (index, frame) in frames.enumerated() {
      // why: Core Graphics counts rows up from the bottom; the first frame goes top left.
      let origin = CGPoint(
        x: Double(index % columns) * cell.width,
        y: Double(height) - Double(index / columns + 1) * cell.height,
      )
      context.draw(frame, in: CGRect(origin: origin, size: cell))
      label(String(format: "%.2f s", times[index]), at: origin, in: context)
    }
    if let sound {
      drawWave(sound, ticks: times.map { ($0 - start) / max(end - start, 0.001) }, in: context)
    }
    guard let image = context.makeImage() else {
      logger.error("preview.failed reason=image")
      throw .renderFailed
    }
    return image
  }

  // MARK: Private

  private static let maxColumns = 6
  private static let waveHeight = 96

  /// `text` in white on a dark strip at the bottom left of a frame drawn from `origin`.
  private static func label(_ text: String, at origin: CGPoint, in context: CGContext) {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, 14, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
        gray: 1,
        alpha: 1,
      ),
    ]
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: attributes)
    )
    let bounds = CTLineGetBoundsWithOptions(line, [])
    context.setFillColor(gray: 0, alpha: 0.7)
    context.fill(CGRect(x: origin.x, y: origin.y, width: bounds.width + 10, height: 22))
    context.textPosition = CGPoint(x: origin.x + 5, y: origin.y + 6)
    CTLineDraw(line, context)
  }

  /// The loudest sample of each pixel column of `sound` along the bottom strip, mirrored around
  /// its middle, with a tick at each fraction in `ticks` (where a frame of the grid sits).
  private static func drawWave(_ sound: [Float], ticks: [Double], in context: CGContext) {
    let width = context.width
    let middle = Double(waveHeight) / 2
    let frames = sound.count / 2
    context.setFillColor(red: 0.45, green: 0.85, blue: 0.75, alpha: 1)
    for column in 0 ..< width where frames > 0 {
      let from = frames * column / width
      let to = max(frames * (column + 1) / width, from + 1)
      var loudest: Float = 0
      for frame in from ..< min(to, frames) {
        loudest = max(loudest, abs(sound[frame * 2]), abs(sound[frame * 2 + 1]))
      }
      let reach = Double(min(loudest, 1)) * (middle - 2)
      context.fill(CGRect(x: Double(column), y: middle - reach, width: 1, height: reach * 2 + 1))
    }
    context.setFillColor(gray: 1, alpha: 0.6)
    for tick in ticks {
      context.fill(CGRect(x: tick * Double(width), y: 0, width: 1, height: 8))
    }
  }

}
