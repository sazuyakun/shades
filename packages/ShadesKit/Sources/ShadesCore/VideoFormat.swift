import Foundation

/// The size and frame rate a timeline is edited and exported at.
public struct VideoFormat: Codable, Hashable, Sendable {
  public init(width: Int, height: Int, framesPerSecond: Int) {
    self.width = width
    self.height = height
    self.framesPerSecond = framesPerSecond
  }

  /// The YouTube master: 4:3 at 1440×1080, 30 fps.
  public static let youTube4x3 = VideoFormat(width: 1440, height: 1080, framesPerSecond: 30)
  /// Instagram Reels and YouTube Shorts: 9:16 at 1080×1920, 30 fps.
  public static let reel9x16 = VideoFormat(width: 1080, height: 1920, framesPerSecond: 30)

  public let width: Int
  public let height: Int
  public let framesPerSecond: Int

  /// The same size at another frame rate (24, 30 or 60 when creating a project).
  public func withFrameRate(_ framesPerSecond: Int) -> VideoFormat {
    VideoFormat(width: width, height: height, framesPerSecond: framesPerSecond)
  }
}
