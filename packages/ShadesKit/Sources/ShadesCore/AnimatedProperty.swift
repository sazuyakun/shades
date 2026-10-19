/// A clip property that keyframes can change over time.
public enum AnimatedProperty: String, Codable, CaseIterable, Sendable {
  case x
  case y
  case scale
  case rotation
  case opacity
}
