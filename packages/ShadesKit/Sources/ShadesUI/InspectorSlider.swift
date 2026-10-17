import SwiftUI

/// A labeled slider with its value written beside it. Changes stream out while dragging; the
/// end of a drag is reported so the whole drag becomes one undo step.
struct InspectorSlider: View {
  let label: String
  let value: Double
  let range: ClosedRange<Double>
  let format: (Double) -> String
  let onChange: (Double) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(label).foregroundStyle(Theme.secondaryText)
        Spacer()
        Text(verbatim: format(value))
          .monospacedDigit()
          .foregroundStyle(Theme.text)
      }
      Slider(
        value: Binding(get: { value }, set: onChange),
        in: range,
        onEditingChanged: { isEditing in
          if !isEditing {
            onEnd()
          }
        },
      )
      .controlSize(.small)
    }
  }
}
