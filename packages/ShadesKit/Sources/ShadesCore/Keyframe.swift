import Foundation

/// The value one property of a clip has at one moment.
public struct Keyframe: Codable, Hashable, Sendable {
  public init(
    property: AnimatedProperty,
    time: MediaTime,
    value: Double,
    easing: Easing = .linear,
  ) {
    self.property = property
    self.time = time
    self.value = value
    self.easing = easing
  }

  public var property: AnimatedProperty
  /// When, in the clip's source time, so the motion stays on the picture when the clip is trimmed
  /// or split.
  public var time: MediaTime
  public var value: Double
  /// How the value travels from this keyframe to the next.
  public var easing: Easing
}
