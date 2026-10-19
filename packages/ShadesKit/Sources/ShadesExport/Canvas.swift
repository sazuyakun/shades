import CoreGraphics
import ShadesCore

/// The frame the 4:3 picture is placed in when exported, centred on black.
public enum Canvas: String, CaseIterable, Codable, Sendable {
  /// The picture alone, at its own size.
  case picture
  /// 16:9 for YouTube: the picture at full height.
  case youtube
  /// 9:16 for Reels and Shorts: the picture 1080 wide, 1080×1920 in all.
  case vertical

  // MARK: Public

  /// The exported frame's size for a timeline of `format`.
  public func size(for format: VideoFormat) -> CGSize {
    let width = Double(format.width)
    let height = Double(format.height)
    return switch self {
    case .picture: CGSize(width: width, height: height)
    // why: video encoders need even sizes.
    case .youtube: CGSize(width: (height * 8 / 9).rounded() * 2, height: height)
    case .vertical: CGSize(width: 1080, height: 1920)
    }
  }

  /// Where the picture sits in the exported frame, from its top left.
  public func pictureRect(for format: VideoFormat) -> CGRect {
    let canvas = size(for: format)
    let scale = min(canvas.width / Double(format.width), canvas.height / Double(format.height))
    let width = (Double(format.width) * scale).rounded()
    let height = (Double(format.height) * scale).rounded()
    return CGRect(
      x: ((canvas.width - width) / 2).rounded(),
      y: ((canvas.height - height) / 2).rounded(),
      width: width,
      height: height,
    )
  }
}
