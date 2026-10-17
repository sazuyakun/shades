import ShadesCore

/// Converts between time on the timeline and horizontal points on screen.
struct TimelineScale {
  let pointsPerSecond: Double

  func x(atSeconds seconds: Double) -> Double {
    seconds * pointsPerSecond
  }

  func x(at time: MediaTime) -> Double {
    time.seconds * pointsPerSecond
  }

  func seconds(atX x: Double) -> Double {
    x / pointsPerSecond
  }
}
