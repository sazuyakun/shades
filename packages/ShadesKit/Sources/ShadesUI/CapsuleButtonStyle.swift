import SwiftUI

/// A button inside a `CapsuleGroup`: quiet grey text, a soft fill when on or pressed.
struct CapsuleButtonStyle: ButtonStyle {
  var isOn = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.callout)
      .foregroundStyle(isOn ? Theme.text : Theme.secondaryText)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(isOn || configuration.isPressed ? Theme.pressed : .clear, in: .capsule)
      .contentShape(.capsule)
  }
}
