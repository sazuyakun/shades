import Foundation

/// Formats seconds the way editors read time.
enum Timecode {
  /// `HH:MM:SS:FF` at the given frame rate, e.g. `00:01:42:18`.
  static func full(_ seconds: Double, framesPerSecond: Int = 30) -> String {
    let totalFrames = Int((max(seconds, 0) * Double(framesPerSecond)).rounded(.down))
    let frames = totalFrames % framesPerSecond
    let totalSeconds = totalFrames / framesPerSecond
    return String(
      format: "%02d:%02d:%02d:%02d",
      totalSeconds / 3600,
      totalSeconds / 60 % 60,
      totalSeconds % 60,
      frames,
    )
  }

  /// `MM:SS` for ruler labels.
  static func short(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%02d:%02d", total / 60, total % 60)
  }
}
