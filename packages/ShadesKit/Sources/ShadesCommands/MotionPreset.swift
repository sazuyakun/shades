/// A ready-made move `ApplyMotion` writes as keyframes.
public enum MotionPreset: String, Codable, CaseIterable, Sendable {
  /// Springs in from nothing.
  case pop
  /// Comes in from an edge of the frame.
  case slideIn
  /// Bobs gently for the whole clip.
  case float
  /// The clips circle together in a ring.
  case orbit
  /// The clips fly apart and fade.
  case scatter
  /// The clips land one after another, like polaroids.
  case stack
}
