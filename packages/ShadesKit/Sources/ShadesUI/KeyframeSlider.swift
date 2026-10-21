import ShadesCore
import SwiftUI

/// A slider for one animatable value, with a diamond that adds or removes a keyframe at the
/// playhead and, on a keyframe, a menu for how it moves on to the next one.
struct KeyframeSlider: View {

  // MARK: Internal

  let property: AnimatedProperty
  let value: Double
  /// The keyframe at the playhead, if there is one.
  let keyHere: Keyframe?
  let isAnimated: Bool
  /// Whether a keyframe can go at the playhead (it's inside the clip).
  let canKey: Bool
  let onChange: (Double) -> Void
  let onEnd: () -> Void
  let onToggleKey: () -> Void
  let onEase: (Keyframe, Easing) -> Void

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      InspectorSlider(
        label: property.label,
        value: value,
        range: property.range,
        format: property.format,
        onChange: onChange,
        onEnd: onEnd,
      )
      if let keyHere {
        Menu {
          Picker(
            "Easing",
            selection: Binding(get: { keyHere.easing }, set: { onEase(keyHere, $0) }),
          ) {
            ForEach(Easing.allCases, id: \.self) { Text(Self.label(of: $0)).tag($0) }
          }
          .pickerStyle(.inline)
        } label: {
          Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("How it moves on to the next keyframe: \(Self.label(of: keyHere.easing))")
      }
      Button(action: onToggleKey) {
        Image(systemName: keyHere == nil ? "diamond" : "diamond.fill")
          .foregroundStyle(isAnimated ? Theme.text : Theme.faintText)
      }
      .buttonStyle(.plain)
      .disabled(!canKey)
      .help(keyHere == nil
        ? "Add a keyframe at the playhead"
        : "Remove the keyframe at the playhead")
    }
  }

  // MARK: Private

  private static func label(of easing: Easing) -> String {
    switch easing {
    case .linear: "Linear"
    case .easeIn: "Ease In"
    case .easeOut: "Ease Out"
    case .easeInOut: "Ease In and Out"
    case .hold: "Hold"
    case .spring: "Spring"
    case .bouncy: "Bouncy"
    }
  }

}
