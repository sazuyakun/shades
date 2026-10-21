import ShadesCore
import SwiftUI

// MARK: - QualifierControls

/// Limits a grade to some colours: a hue range and a brightness range, with soft edges.
struct QualifierControls: View {

  let qualifier: Qualifier?
  let onChange: (Qualifier?) -> Void
  let onEnd: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("Only change some colours", isOn: Binding(
        get: { qualifier != nil },
        set: { onChange($0 ? Qualifier() : nil) },
      ))
      .help("A qualifier: the grade changes only the colours picked here, like skin or sky")
      if let qualifier {
        Rectangle()
          .fill(LinearGradient(
            colors: stride(from: 0.0, through: 1, by: 1 / 6).map {
              Color(hue: $0, saturation: 0.8, brightness: 0.9)
            },
            startPoint: .leading,
            endPoint: .trailing,
          ))
          .frame(height: 6)
          .clipShape(.capsule)
        ForEach(QualifierField.allCases, id: \.self) { field in
          InspectorSlider(
            label: field.label,
            value: qualifier[keyPath: field.keyPath],
            range: field.range,
            format: field.format,
            onChange: { value in
              var changed = qualifier
              changed[keyPath: field.keyPath] = value
              onChange(changed)
            },
            onEnd: onEnd,
          )
        }
      }
    }
  }

}

// MARK: - QualifierField

/// A qualifier slider.
private enum QualifierField: CaseIterable {
  case hue
  case hueWidth
  case minSaturation
  case darkest
  case brightest
  case softness

  // MARK: Internal

  var label: String {
    switch self {
    case .hue: "Hue"
    case .hueWidth: "Hue Range"
    case .minSaturation: "Least Colour"
    case .darkest: "Darkest"
    case .brightest: "Brightest"
    case .softness: "Softness"
    }
  }

  var keyPath: WritableKeyPath<Qualifier, Double> {
    switch self {
    case .hue: \.hue
    case .hueWidth: \.hueWidth
    case .minSaturation: \.minSaturation
    case .darkest: \.brightness[0]
    case .brightest: \.brightness[1]
    case .softness: \.softness
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .hue,
         .minSaturation,
         .darkest,
         .brightest: 0 ... 1
    case .hueWidth,
         .softness: 0 ... 0.5
    }
  }

  func format(_ value: Double) -> String {
    self == .hue ? "\(Int((value * 360).rounded()))°" : "\(Int((value * 100).rounded()))%"
  }
}
