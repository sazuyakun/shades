// MARK: - ClipTransform

/// How a clip sits in the frame. At `identity` the clip is fitted inside the frame, upright,
/// centered and flat.
public struct ClipTransform: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    x: Double = 0,
    y: Double = 0,
    scale: Double = 1,
    rotation: Double = 0,
    tiltX: Double = 0,
    tiltY: Double = 0,
    depth: Double = 0,
  ) {
    self.x = x
    self.y = y
    self.scale = scale
    self.rotation = rotation
    self.tiltX = tiltX
    self.tiltY = tiltY
    self.depth = depth
  }

  // MARK: Public

  public static let identity = ClipTransform()

  /// Horizontal offset as a fraction of the frame width; positive moves right.
  public var x: Double
  /// Vertical offset as a fraction of the frame height; positive moves down.
  public var y: Double
  /// Size relative to fitting the frame; 1 fits, 2 is twice as big.
  public var scale: Double
  /// Clockwise rotation in degrees.
  public var rotation: Double
  /// Tilt back (positive, the top leans away) or forward, in degrees, with perspective.
  public var tiltX: Double
  /// Turn to the side (positive, the right edge leans away), in degrees, with perspective.
  public var tiltY: Double
  /// Distance towards the viewer as a fraction of the frame height; negative is further away.
  public var depth: Double

}

// MARK: Codable

extension ClipTransform: Codable {

  // MARK: Lifecycle

  /// Reads a transform, including ones saved before layers could tilt (flat, at depth 0).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      x: container.decode(Double.self, forKey: .x),
      y: container.decode(Double.self, forKey: .y),
      scale: container.decode(Double.self, forKey: .scale),
      rotation: container.decode(Double.self, forKey: .rotation),
      tiltX: container.decodeIfPresent(Double.self, forKey: .tiltX) ?? 0,
      tiltY: container.decodeIfPresent(Double.self, forKey: .tiltY) ?? 0,
      depth: container.decodeIfPresent(Double.self, forKey: .depth) ?? 0,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case x
    case y
    case scale
    case rotation
    case tiltX
    case tiltY
    case depth
  }

}
