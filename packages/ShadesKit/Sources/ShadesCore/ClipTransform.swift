/// How a clip sits in the frame. At `identity` the clip is fitted inside the frame, upright and
/// centered.
public struct ClipTransform: Codable, Hashable, Sendable {
  public init(x: Double = 0, y: Double = 0, scale: Double = 1, rotation: Double = 0) {
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
  }

  public static let identity = ClipTransform()

  /// Horizontal offset as a fraction of the frame width; positive moves right.
  public var x: Double
  /// Vertical offset as a fraction of the frame height; positive moves down.
  public var y: Double
  /// Size relative to fitting the frame; 1 fits, 2 is twice as big.
  public var scale: Double
  /// Clockwise rotation in degrees.
  public var rotation: Double
}
