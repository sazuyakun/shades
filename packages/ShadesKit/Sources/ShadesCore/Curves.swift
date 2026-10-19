/// Tone curves: each a list of points from dark to light (input → output, 0 to 1). The master
/// curve shapes all three colours; the others shape one. A curve left out is a straight line.
public struct Curves: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    master: [DrawingPoint]? = nil,
    red: [DrawingPoint]? = nil,
    green: [DrawingPoint]? = nil,
    blue: [DrawingPoint]? = nil,
  ) {
    self.master = master
    self.red = red
    self.green = green
    self.blue = blue
  }

  // MARK: Public

  public var master: [DrawingPoint]?
  public var red: [DrawingPoint]?
  public var green: [DrawingPoint]?
  public var blue: [DrawingPoint]?

  /// A curve's output for `input`, with smooth bends between its points (flat beyond them).
  public static func value(of points: [DrawingPoint]?, at input: Double) -> Double {
    guard
      let points = points?.sorted(by: { $0.x < $1.x }), let first = points.first,
      let last = points.last
    else {
      return input
    }
    guard input > first.x else {
      return first.y
    }
    guard let next = points.firstIndex(where: { $0.x >= input }) else {
      return last.y
    }
    let from = points[next - 1]
    let to = points[next]
    let span = to.x - from.x
    guard span > 0 else {
      return to.y
    }
    let t = (input - from.x) / span
    // why: smoothstep between points bends the curve without overshooting, unlike a spline.
    let eased = t * t * (3 - 2 * t)
    return from.y + (to.y - from.y) * eased
  }

}
