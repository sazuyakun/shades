import Foundation

/// The size and frame rate a timeline is edited and exported at. The picture is always 4:3.
public struct VideoFormat: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(width: Int, height: Int, framesPerSecond: Int) {
    self.width = width
    self.height = height
    self.framesPerSecond = framesPerSecond
  }

  // MARK: Public

  /// The default master: 2880×2160 at 24 fps.
  public static let standard = VideoFormat(width: 2880, height: 2160, framesPerSecond: 24)
  /// The lighter master: 1440×1080 at 24 fps.
  public static let half = VideoFormat(width: 1440, height: 1080, framesPerSecond: 24)
  /// The frame rates a project can use. Each divides `MediaTime.timelineTimescale`.
  public static let frameRates = [24, 30, 60]

  public let width: Int
  public let height: Int
  public let framesPerSecond: Int

  /// The length of one frame.
  public var frameDuration: MediaTime {
    MediaTime(
      value: Int64(MediaTime.timelineTimescale) / Int64(framesPerSecond),
      timescale: MediaTime.timelineTimescale,
    )
  }

  /// The same size at another frame rate.
  public func withFrameRate(_ framesPerSecond: Int) -> VideoFormat {
    VideoFormat(width: width, height: height, framesPerSecond: framesPerSecond)
  }

}
