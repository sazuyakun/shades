/// A clip property that keyframes can change over time.
public enum AnimatedProperty: String, Codable, CaseIterable, Sendable {
  case x
  case y
  case scale
  case rotation
  case tiltX
  case tiltY
  case depth
  case opacity
  /// Sound level, as a gain (1 unchanged).
  case volume
  /// How fast the clip plays its media (1 normal, 2 twice as fast). Its keyframes make a ramp.
  case speed

  // MARK: Public

  /// Whether it changes how the picture is placed or drawn (everything but volume and speed).
  public var isVisual: Bool {
    self != .volume && self != .speed
  }
}
