// MARK: - LayerMask

/// A shape that hides or reveals part of a layer. It sits on the layer's own picture, so it
/// moves, turns and scales with it.
public struct LayerMask: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    shape: MaskShape = .ellipse,
    x: Double = 0.5,
    y: Double = 0.5,
    width: Double = 0.5,
    height: Double = 0.5,
    points: [DrawingPoint] = [],
    feather: Double = 0,
    expansion: Double = 0,
    inverted: Bool = false,
    opacity: Double = 1,
    mode: MaskMode = .add,
    keyframes: [ShapeKeyframe] = [],
  ) {
    self.shape = shape
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.points = points
    self.feather = feather
    self.expansion = expansion
    self.inverted = inverted
    self.opacity = opacity
    self.mode = mode
    self.keyframes = keyframes
  }

  // MARK: Public

  public var shape: MaskShape
  /// The centre, as fractions of the layer's upright picture from its top left.
  public var x: Double
  public var y: Double
  /// The size of its box, as fractions of the picture.
  public var width: Double
  public var height: Double
  /// A path's outline, as fractions of the box from its top left.
  public var points: [DrawingPoint]
  /// How far the edge fades, as a fraction of the picture's height.
  public var feather: Double
  /// How far the edge is pushed out (positive) or pulled in, as a fraction of the picture's
  /// height.
  public var expansion: Double
  /// Works on everything outside the shape instead of inside it.
  public var inverted: Bool
  /// How strongly it reveals or hides, 0 to 1.
  public var opacity: Double
  /// How it joins the masks before it.
  public var mode: MaskMode
  /// Where its box and outline are over time, overriding the fixed ones while present.
  public var keyframes: [ShapeKeyframe]

  /// The mask as it is at `time` (in its clip's source time), moved and reshaped by its
  /// keyframes.
  public func placed(at time: MediaTime) -> LayerMask {
    guard let key = keyframes.shape(at: time) else {
      return self
    }
    var placed = self
    placed.x = key.x
    placed.y = key.y
    placed.width = key.width
    placed.height = key.height
    placed.points = shape == .path && !key.points.isEmpty ? key.points : points
    return placed
  }

  /// Its box and outline now, as a keyframe at `time`.
  public func keyframe(at time: MediaTime, easing: Easing = .linear) -> ShapeKeyframe {
    let now = placed(at: time)
    return ShapeKeyframe(
      time: time,
      x: now.x,
      y: now.y,
      width: now.width,
      height: now.height,
      points: shape == .path ? now.points : [],
      easing: easing,
    )
  }

}

// MARK: Codable

extension LayerMask: Codable {

  // MARK: Lifecycle

  /// Reads a mask where any field may be left out (a hard ellipse in the middle, adding).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = LayerMask()
    try self.init(
      shape: container.decodeIfPresent(MaskShape.self, forKey: .shape) ?? base.shape,
      x: container.decodeIfPresent(Double.self, forKey: .x) ?? base.x,
      y: container.decodeIfPresent(Double.self, forKey: .y) ?? base.y,
      width: container.decodeIfPresent(Double.self, forKey: .width) ?? base.width,
      height: container.decodeIfPresent(Double.self, forKey: .height) ?? base.height,
      points: container.decodeIfPresent([DrawingPoint].self, forKey: .points) ?? [],
      feather: container.decodeIfPresent(Double.self, forKey: .feather) ?? base.feather,
      expansion: container.decodeIfPresent(Double.self, forKey: .expansion) ?? base.expansion,
      inverted: container.decodeIfPresent(Bool.self, forKey: .inverted) ?? base.inverted,
      opacity: container.decodeIfPresent(Double.self, forKey: .opacity) ?? base.opacity,
      mode: container.decodeIfPresent(MaskMode.self, forKey: .mode) ?? base.mode,
      keyframes: container.decodeIfPresent([ShapeKeyframe].self, forKey: .keyframes) ?? [],
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case shape
    case x
    case y
    case width
    case height
    case points
    case feather
    case expansion
    case inverted
    case opacity
    case mode
    case keyframes
  }

}
