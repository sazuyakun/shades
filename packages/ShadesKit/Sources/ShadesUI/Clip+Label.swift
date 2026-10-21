import ShadesCore

extension Clip {
  /// What the timeline calls a clip that isn't media or text.
  var label: String? {
    switch source {
    case .drawing: "Drawing"
    case .adjustment: "Adjustment"
    case .media,
         .text: nil
    }
  }

  /// How the timeline marks a clip that doesn't play at normal speed: "Freeze", "Ramp" or
  /// "2×".
  var speedLabel: String? {
    if isFrozen {
      return "Freeze"
    }
    if hasSpeedRamp {
      return "Ramp"
    }
    return speed == 1 ? nil : AnimatedProperty.speed.format(speed)
  }
}
