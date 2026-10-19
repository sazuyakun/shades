import Foundation

// MARK: - Easing

/// How a value travels from one keyframe to the next.
public enum Easing: String, Codable, CaseIterable, Sendable {
  /// At a steady speed.
  case linear
  /// Starting slowly.
  case easeIn
  /// Arriving slowly.
  case easeOut
  /// Starting and arriving slowly.
  case easeInOut
  /// Staying put, then jumping at the next keyframe.
  case hold
  /// Like a spring: quick, overshooting a little, then settling.
  case spring
  /// Like a loose spring: overshooting and wobbling before it settles.
  case bouncy

  // MARK: Public

  /// How far along the way the value is (0 at the start, 1 on arrival) when `fraction` of the
  /// time between the keyframes has passed. Springs go past 1 on the way.
  public func progress(_ fraction: Double) -> Double {
    let time = min(max(fraction, 0), 1)
    switch self {
    case .linear:
      return time
    case .easeIn:
      return time * time * time
    case .easeOut:
      return 1 - pow(1 - time, 3)
    case .easeInOut:
      return time < 0.5 ? 4 * time * time * time : 1 - pow(-2 * time + 2, 3) / 2
    case .hold:
      return time < 1 ? 0 : 1
    case .spring:
      return Self.spring(time, damping: 0.75, frequency: 11)
    case .bouncy:
      return Self.spring(time, damping: 0.35, frequency: 20)
    }
  }

  // MARK: Private

  /// A damped spring released at 0 towards 1, tuned to settle by the end (`time` 1).
  private static func spring(_ time: Double, damping: Double, frequency: Double) -> Double {
    guard time < 1 else {
      return 1
    }
    let decay = damping * frequency
    let wobble = frequency * (1 - damping * damping).squareRoot()
    return 1 - exp(-decay * time) * (cos(wobble * time) + decay / wobble * sin(wobble * time))
  }
}
