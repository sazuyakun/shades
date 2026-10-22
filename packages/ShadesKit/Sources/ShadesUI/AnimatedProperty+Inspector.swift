import ShadesCommands
import ShadesCore

extension AnimatedProperty {

  // MARK: Internal

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
    case .bend: "Bend"
    case .opacity: "Opacity"
    case .volume: "Volume"
    case .speed: "Speed"
    case .pathOffset: "Along Path"
    case .portal: "Zoom Through"
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
    case .bend: -180 ... 180
    case .opacity: 0 ... 1
    case .volume: 0 ... 2
    case .speed: 0.1 ... 4
    case .pathOffset: -1 ... 1
    case .portal: 0 ... 8
    }
  }

  /// The value as the inspector writes it.
  func format(_ value: Double) -> String {
    switch self {
    case .rotation,
         .tiltX,
         .tiltY,
         .bend: "\(Int(value.rounded()))°"
    case .speed: "\(value.formatted(.number.precision(.fractionLength(0 ... 2))))×"
    case .portal: "\(value.formatted(.number.precision(.fractionLength(0 ... 2)))) frames"
    default: "\(Int((value * 100).rounded()))%"
    }
  }

  /// Whether the Video tab shows this property for `clip`: a path offset only on text along a
  /// path. Sound, speed and the endless zoom have their own tabs.
  func isShown(for clip: Clip) -> Bool {
    switch self {
    case .volume,
         .speed,
         .portal: false
    case .pathOffset: clip.text?.path != nil
    default: true
    }
  }

  /// The edit that sets this property's fixed value on `clip`.
  func fixedEdit(_ value: Double, on clip: Clip) -> any ToolCommand {
    switch self {
    case .x: SetClip(clipID: clip.id, x: value)
    case .y: SetClip(clipID: clip.id, y: value)
    case .scale: SetClip(clipID: clip.id, scale: value)
    case .rotation: SetClip(clipID: clip.id, rotation: value)
    case .tiltX: SetClip(clipID: clip.id, tiltX: value)
    case .tiltY: SetClip(clipID: clip.id, tiltY: value)
    case .depth: SetClip(clipID: clip.id, depth: value)
    case .bend: SetClip(clipID: clip.id, bend: value)
    case .opacity: SetClip(clipID: clip.id, opacity: value)
    case .volume: SetClip(clipID: clip.id, volume: value)
    case .speed: SetClip(clipID: clip.id, speed: value)
    case .pathOffset: SetText(clipID: clip.id, pathOffset: value)
    case .portal: SetLook(clipIDs: [clip.id], effects: travelled(clip.effects, to: value))
    }
  }

  // MARK: Private

  /// `effects` with their endless zoom travelled to `travel`.
  private func travelled(_ effects: Effects?, to travel: Double) -> Effects {
    var effects = effects ?? Effects()
    effects.portal?.travel = travel
    return effects
  }

}
