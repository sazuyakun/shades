import ShadesCore

extension Clip {
  /// What the timeline calls a clip that isn't media or text.
  var label: String? {
    switch source {
    case .drawing: "Drawing"
    case .adjustment: "Adjustment"
    case .media,
         .text: nil
    }
  }
}
