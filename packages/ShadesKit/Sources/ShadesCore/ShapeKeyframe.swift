// MARK: - ShapeKeyframe

/// Where a mask or grade window is, how big, and its outline (for a path mask), at one moment.
public struct ShapeKeyframe: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    time: MediaTime,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    points: [DrawingPoint] = [],
    easing: Easing = .linear,
  ) {
    self.time = time
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.points = points
    self.easing = easing
  }

  // MARK: Public

  /// When, in the clip's source time, like clip keyframes.
  public var time: MediaTime
  /// The centre and size, in the units of the shape it moves.
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double
  /// A path mask's outline inside its box; empty for other shapes.
  public var points: [DrawingPoint]
  /// How the shape travels from this keyframe to the next.
  public var easing: Easing

  /// The shape `fraction` of the way from this keyframe to `next`, shaped by this one's easing.
  /// An outline with a different number of points jumps at the next keyframe instead.
  public func value(towards next: ShapeKeyframe, at fraction: Double) -> ShapeKeyframe {
    let progress = easing.progress(fraction)
    func mix(_ from: Double, _ to: Double) -> Double {
      from + (to - from) * progress
    }
    let points =
      if points.count == next.points.count {
        zip(points, next.points).map { DrawingPoint(x: mix($0.x, $1.x), y: mix($0.y, $1.y)) }
      } else {
        progress < 1 ? points : next.points
      }
    return ShapeKeyframe(
      time: time,
      x: mix(x, next.x),
      y: mix(y, next.y),
      width: mix(width, next.width),
      height: mix(height, next.height),
      points: points,
      easing: easing,
    )
  }

}

// MARK: Codable

extension ShapeKeyframe: Codable {

  // MARK: Lifecycle

  /// Reads a keyframe whose outline and easing may be left out.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      time: container.decode(MediaTime.self, forKey: .time),
      x: container.decode(Double.self, forKey: .x),
      y: container.decode(Double.self, forKey: .y),
      width: container.decode(Double.self, forKey: .width),
      height: container.decode(Double.self, forKey: .height),
      points: container.decodeIfPresent([DrawingPoint].self, forKey: .points) ?? [],
      easing: container.decodeIfPresent(Easing.self, forKey: .easing) ?? .linear,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case time
    case x
    case y
    case width
    case height
    case points
    case easing
  }

}

// MARK: - [ShapeKeyframe] + Easing

extension [ShapeKeyframe] {
  /// The shape at `time` (in the keyframes' own time): eased between the keyframes around it,
  /// held before the first and after the last; `nil` when there are none.
  public func shape(at time: MediaTime) -> ShapeKeyframe? {
    sorted { $0.time < $1.time }.eased(
      at: time.seconds,
      time: \.time.seconds,
      hold: { $0 },
      blend: { from, to, fraction in from.value(towards: to, at: fraction) },
    )
  }

  /// Adds `key`, replacing a keyframe at the same moment, keeping them in time order.
  public mutating func set(_ key: ShapeKeyframe) {
    removeAll { $0.time == key.time }
    append(key)
    sort { $0.time < $1.time }
  }
}
