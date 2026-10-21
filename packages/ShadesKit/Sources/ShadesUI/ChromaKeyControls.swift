import ShadesCore
import SwiftUI

/// Keys out one colour (a green screen): on or off, which colour, how far from it counts, and
/// how soft the edge is.
struct ChromaKeyControls: View {

  // MARK: Internal

  let key: ChromaKey?
  let onChange: (ChromaKey?) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Toggle("Key out a colour", isOn: Binding(
          get: { key != nil },
          set: { onChange($0 ? ChromaKey() : nil) },
        ))
        Spacer()
        if let key {
          ColorPicker("Colour", selection: Binding(get: { key.color.color }, set: { picked in
            guard let color = HexColor(picked) else {
              return
            }
            var changed = key
            changed.color = color
            onChange(changed)
          }))
          .labelsHidden()
          .help("The background colour to make see-through")
        }
      }
      if let key {
        InspectorSlider(
          label: "Tolerance",
          value: key.tolerance,
          range: 0 ... 1,
          format: percent,
          onChange: { value in
            var changed = key
            changed.tolerance = value
            onChange(changed)
          },
          onEnd: onEnd,
        )
        .help("How far from the colour still counts as background")
        InspectorSlider(
          label: "Edge Softness",
          value: key.softness,
          range: 0 ... 1,
          format: percent,
          onChange: { value in
            var changed = key
            changed.softness = value
            onChange(changed)
          },
          onEnd: onEnd,
        )
      }
    }
  }

  // MARK: Private

  private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
  }

}
