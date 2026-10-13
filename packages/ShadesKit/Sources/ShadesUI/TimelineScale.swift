import Foundation

/// Converts between seconds on the timeline and horizontal points on screen.
struct TimelineScale {
  /// Fits the whole timeline into `width`, showing at least 30 seconds.
  init(width: Double, duration: Double) {
    pointsPerSecond = max(width, 1) / max(duration * 1.1, 30)
  }

  let pointsPerSecond: Double

  func x(atSeconds seconds: Double) -> Double {
    seconds * pointsPerSecond
  }

  func seconds(atX x: Double) -> Double {
    x / pointsPerSecond
  }
}
