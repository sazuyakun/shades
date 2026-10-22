import ShadesCore
import SwiftUI

/// How a keyframe moves on to the next one (linear, eased, hold or springy), as a small menu
/// with a tick on the current choice.
struct EasingMenu: View {

  // MARK: Internal

  let easing: Easing
  let onPick: (Easing) -> Void

  var body: some View {
    Menu {
      Picker("Easing", selection: Binding(get: { easing }, set: onPick)) {
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
    .help("How it moves on to the next keyframe: \(Self.label(of: easing))")
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
