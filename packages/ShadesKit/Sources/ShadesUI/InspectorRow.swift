import SwiftUI

/// One inspector row: a grey label on the left, the value in a rounded field on the right.
struct InspectorRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label).foregroundStyle(Theme.secondaryText)
      Spacer()
      Text(verbatim: value)
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.raised, in: .rect(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.strongHairline))
    }
  }
}
