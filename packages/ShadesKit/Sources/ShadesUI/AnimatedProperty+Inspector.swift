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
    case .opacity: "Opacity"
    }
  }

  /// The slider's range.
  var range: ClosedRange<Double> {
    switch self {
    case .x,
         .y: -1 ... 1
    case .scale: 0.05 ... 4
    case .rotation: -180 ... 180
    case .opacity: 0 ... 1
    }
  }

  /// The value as the inspector writes it.
  func format(_ value: Double) -> String {
    self == .rotation ? "\(Int(value.rounded()))°" : "\(Int((value * 100).rounded()))%"
  }

  /// The edit that sets this property's fixed value on `clip`.
  func fixedEdit(_ value: Double, on clip: Clip.ID) -> SetClip {
    switch self {
    case .x: SetClip(clipID: clip, x: value)
    case .y: SetClip(clipID: clip, y: value)
    case .scale: SetClip(clipID: clip, scale: value)
    case .rotation: SetClip(clipID: clip, rotation: value)
    case .opacity: SetClip(clipID: clip, opacity: value)
    }
  }
}
