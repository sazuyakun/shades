/// A clip property that keyframes can change over time.
public enum AnimatedProperty: String, Codable, CaseIterable, Sendable {
  case x
  case y
  case scale
  case rotation
  case tiltX
  case tiltY
  case depth
  /// Curves the layer around an upright axis (`ClipTransform.bend`).
  case bend
  case opacity
  /// Sound level, as a gain (1 unchanged).
  case volume
  /// How fast the clip plays its media (1 normal, 2 twice as fast). Its keyframes make a ramp.
  case speed
  /// How far text on a path has moved along it (`TextPath.offset`).
  case pathOffset

  // MARK: Public

  /// What a camera move animates: where the picture is seen from.
  public static let cameraMoves: [AnimatedProperty] = [
    .x,
    .y,
    .scale,
    .rotation,
    .tiltX,
    .tiltY,
    .depth,
  ]
}
