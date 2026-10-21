import CoreGraphics

/// A path of straight steps that text is laid along: where a distance along it lands, and which
/// way it points there.
struct Polyline {

  // MARK: Lifecycle

  init(_ points: [CGPoint]) {
    self.points = points
    var total: CGFloat = 0
    var distances: [CGFloat] = [0]
    for (from, to) in zip(points, points.dropFirst()) {
      total += hypot(to.x - from.x, to.y - from.y)
      distances.append(total)
    }
    self.distances = distances
    // why: a closed path (a circle, a loop) has no ends, so text travelling along it wraps round.
    isClosed = points.count > 2 && points.first.flatMap { first in
      points.last.map { hypot($0.x - first.x, $0.y - first.y) < 0.5 }
    } == true
  }

  // MARK: Internal

  /// The path's whole length.
  var length: CGFloat {
    distances.last ?? 0
  }

  /// The point `distance` along the path and its direction there (radians from the x axis), or
  /// `nil` past either end of an open path.
  func locate(_ distance: CGFloat) -> (point: CGPoint, angle: CGFloat)? {
    guard length > 0 else {
      return nil
    }
    var along = distance
    if isClosed {
      along = along.truncatingRemainder(dividingBy: length)
      if along < 0 {
        along += length
      }
    }
    guard along >= 0, along <= length else {
      return nil
    }
    let step = max((distances.firstIndex { $0 >= along } ?? 1) - 1, 0)
    let from = points[step]
    let to = points[min(step + 1, points.count - 1)]
    let span = distances[min(step + 1, distances.count - 1)] - distances[step]
    let fraction = span > 0 ? (along - distances[step]) / span : 0
    return (
      CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction),
      atan2(to.y - from.y, to.x - from.x),
    )
  }

  // MARK: Private

  private let points: [CGPoint]
  /// How far along the path each point is.
  private let distances: [CGFloat]
  private let isClosed: Bool

}
