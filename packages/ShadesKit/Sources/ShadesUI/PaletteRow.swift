import SwiftUI

/// One action in the palette: its name and shortcut.
struct PaletteRow: View {
  let action: EditorAction
  let isHighlighted: Bool

  var body: some View {
    HStack {
      Text(action.title)
      Spacer()
      Text(action.shortcut.label)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(Theme.secondaryText)
    }
    .padding(.horizontal, 10)
    .frame(height: 30)
    .background(isHighlighted ? Theme.pressed : .clear, in: .rect(cornerRadius: 6))
    .contentShape(.rect)
  }
}
