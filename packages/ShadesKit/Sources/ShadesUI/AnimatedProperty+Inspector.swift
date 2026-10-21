import ShadesCommands
import ShadesCore

extension AnimatedProperty {
  /// The slider's label.
  var label: String {
    switch self {
    case .x: "Position X"
    case .y: "Position Y"
    case .scale: "Scale"
    case .rotation: "Rotation"
    case .tiltX: "Tilt"
    case .tiltY: "Turn"
    case .depth: "Depth"
    case .opacity: "Opacity"
    case .volume: "Volume"
    case .speed: "Speed"
    }
  }

  /// The slider's range.
  var range: ClosedRange<Double> {
    switch self {
    case .x,
         .y: -1 ... 1
    case .scale: 0.05 ... 4
    case .rotation: -180 ... 180
    case .tiltX,
         .tiltY: -80 ... 80
    case .depth: -3 ... 1
    case .opacity: 0 ... 1
    case .volume: 0 ... 2
    case .speed: 0.1 ... 4
    }
  }

  /// The value as the inspector writes it.
  func format(_ value: Double) -> String {
    switch self {
    case .rotation,
         .tiltX,
         .tiltY: "\(Int(value.rounded()))°"
    case .speed: "\(value.formatted(.number.precision(.fractionLength(0 ... 2))))×"
    default: "\(Int((value * 100).rounded()))%"
    }
  }

  /// The edit that sets this property's fixed value on `clip`.
  func fixedEdit(_ value: Double, on clip: Clip.ID) -> SetClip {
    switch self {
    case .x: SetClip(clipID: clip, x: value)
    case .y: SetClip(clipID: clip, y: value)
    case .scale: SetClip(clipID: clip, scale: value)
    case .rotation: SetClip(clipID: clip, rotation: value)
    case .tiltX: SetClip(clipID: clip, tiltX: value)
    case .tiltY: SetClip(clipID: clip, tiltY: value)
    case .depth: SetClip(clipID: clip, depth: value)
    case .opacity: SetClip(clipID: clip, opacity: value)
    case .volume: SetClip(clipID: clip, volume: value)
    case .speed: SetClip(clipID: clip, speed: value)
    }
  }
}
