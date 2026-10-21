import ShadesCore
import SwiftUI

// MARK: - GradeWindowControls

/// Limits a grade to a soft ellipse or rectangle, or keeps it out of one.
struct GradeWindowControls: View {

  let window: GradeWindow?
  let onChange: (GradeWindow?) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("Only change inside a shape", isOn: Binding(
        get: { window != nil },
        set: { onChange($0 ? GradeWindow() : nil) },
      ))
      .help("A window: the grade changes only inside (or outside) a soft shape, like a face")
      if let window {
        Picker("Shape", selection: Binding(
          get: { window.isEllipse },
          set: { isEllipse in
            var changed = window
            changed.isEllipse = isEllipse
            onChange(changed)
          },
        )) {
          Text("Ellipse").tag(true)
          Text("Rectangle").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        ForEach(WindowField.allCases, id: \.self) { field in
          InspectorSlider(
            label: field.label,
            value: window[keyPath: field.keyPath],
            range: field.range,
            format: { "\(Int(($0 * 100).rounded()))%" },
            onChange: { value in
              var changed = window
              changed[keyPath: field.keyPath] = value
              onChange(changed)
            },
            onEnd: onEnd,
          )
        }
        Toggle("Change outside the shape instead", isOn: Binding(
          get: { window.inverted },
          set: { inverted in
            var changed = window
            changed.inverted = inverted
            onChange(changed)
          },
        ))
      }
    }
  }

}

// MARK: - WindowField

/// A window slider.
private enum WindowField: CaseIterable {
  case x
  case y
  case width
  case height
  case softness

  // MARK: Internal

  var label: String {
    switch self {
    case .x: "Across"
    case .y: "Down"
    case .width: "Width"
    case .height: "Height"
    case .softness: "Softness"
    }
  }

  var keyPath: WritableKeyPath<GradeWindow, Double> {
    switch self {
    case .x: \.x
    case .y: \.y
    case .width: \.width
    case .height: \.height
    case .softness: \.softness
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .x,
         .y,
         .softness: 0 ... 1
    case .width,
         .height: 0.02 ... 1.5
    }
  }
}
