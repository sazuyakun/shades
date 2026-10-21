// MARK: - DrawingPoint

/// A point as fractions of an area from its top left: the frame for a drawn stroke, the box of
/// a path mask. Written as `[x, y]`.
public struct DrawingPoint: Hashable, Sendable {
  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public var x: Double
  public var y: Double
}

// MARK: Codable

extension DrawingPoint: Codable {

  // MARK: Lifecycle

  public init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    try self.init(x: container.decode(Double.self), y: container.decode(Double.self))
  }

  // MARK: Public

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(x)
    try container.encode(y)
  }

}
