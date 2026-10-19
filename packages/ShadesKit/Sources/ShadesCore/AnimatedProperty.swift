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

  // MARK: Public

  /// Whether it changes the picture (everything but volume).
  public var isVisual: Bool {
    self != .volume
  }
}
