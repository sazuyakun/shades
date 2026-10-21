// MARK: - GradeWindow

/// A soft shape a grade is limited to (or kept out of), like a vignette pointed at a face.
public struct GradeWindow: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    isEllipse: Bool = true,
    x: Double = 0.5,
    y: Double = 0.5,
    width: Double = 0.5,
    height: Double = 0.5,
    softness: Double = 0.2,
    inverted: Bool = false,
    keyframes: [ShapeKeyframe] = [],
  ) {
    self.isEllipse = isEllipse
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.softness = softness
    self.inverted = inverted
    self.keyframes = keyframes
  }

  // MARK: Public

  /// An ellipse, or a rectangle when false.
  public var isEllipse: Bool
  /// The centre, as fractions of the frame from its top left.
  public var x: Double
  public var y: Double
  /// The size, as fractions of the frame.
  public var width: Double
  public var height: Double
  /// How far the edge fades, as a fraction of the shape's size.
  public var softness: Double
  /// Grade outside the shape instead of inside.
  public var inverted: Bool
  /// Where it is and how big over time (in its clip's source time, centre and size as fractions
  /// of the frame), overriding the fixed ones while present.
  public var keyframes: [ShapeKeyframe]

  /// The window as it is at `time` (in its clip's source time), moved by its keyframes.
  public func placed(at time: MediaTime) -> GradeWindow {
    guard let key = keyframes.shape(at: time) else {
      return self
    }
    var placed = self
    placed.x = key.x
    placed.y = key.y
    placed.width = key.width
    placed.height = key.height
    return placed
  }

  /// Where it is now, as a keyframe at `time`.
  public func keyframe(at time: MediaTime, easing: Easing = .linear) -> ShapeKeyframe {
    let now = placed(at: time)
    return ShapeKeyframe(
      time: time,
      x: now.x,
      y: now.y,
      width: now.width,
      height: now.height,
      easing: easing,
    )
  }

}

// MARK: Codable

extension GradeWindow: Codable {

  // MARK: Lifecycle

  /// Reads a window where any field may be left out (a soft ellipse in the middle).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = GradeWindow()
    try self.init(
      isEllipse: container.decodeIfPresent(String.self, forKey: .shape).map { $0 != "rectangle" }
        ?? base.isEllipse,
      x: container.decodeIfPresent(Double.self, forKey: .x) ?? base.x,
      y: container.decodeIfPresent(Double.self, forKey: .y) ?? base.y,
      width: container.decodeIfPresent(Double.self, forKey: .width) ?? base.width,
      height: container.decodeIfPresent(Double.self, forKey: .height) ?? base.height,
      softness: container.decodeIfPresent(Double.self, forKey: .softness) ?? base.softness,
      inverted: container.decodeIfPresent(Bool.self, forKey: .inverted) ?? base.inverted,
      keyframes: container.decodeIfPresent([ShapeKeyframe].self, forKey: .keyframes) ?? [],
    )
  }

  // MARK: Public

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(isEllipse ? "ellipse" : "rectangle", forKey: .shape)
    try container.encode(x, forKey: .x)
    try container.encode(y, forKey: .y)
    try container.encode(width, forKey: .width)
    try container.encode(height, forKey: .height)
    try container.encode(softness, forKey: .softness)
    try container.encode(inverted, forKey: .inverted)
    try container.encode(keyframes, forKey: .keyframes)
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case shape
    case x
    case y
    case width
    case height
    case softness
    case inverted
    case keyframes
  }

}
