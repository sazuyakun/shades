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
  ) {
    self.isEllipse = isEllipse
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.softness = softness
    self.inverted = inverted
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
  }

}
