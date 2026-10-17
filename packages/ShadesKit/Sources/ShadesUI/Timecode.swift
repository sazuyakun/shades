import Foundation

/// Formats seconds the way editors read time.
enum Timecode {

  // MARK: Internal

  /// `HH:MM:SS:FF` at the given frame rate, e.g. `00:01:42:18`.
  static func full(_ seconds: Double, framesPerSecond: Int) -> String {
    let totalFrames = Int((safe(seconds) * Double(framesPerSecond)).rounded(.down))
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
    let total = Int(safe(seconds).rounded())
    return String(format: "%02d:%02d", total / 60, total % 60)
  }

  // MARK: Private

  /// The time if it's a real, non-negative number; otherwise 0 (players report NaN while
  /// loading).
  private static func safe(_ seconds: Double) -> Double {
    seconds.isFinite ? max(seconds, 0) : 0
  }

}
