import ShadesPolish
import SwiftUI

/// The colour each kind of Polish edit shows in on the timeline and in the checklist.
enum PolishColors {
  static func color(of kind: PolishKind) -> Color {
    switch kind {
    case .silence: Theme.negative
    case .filler: Theme.marker
    case .retake: Color(red: 0.35, green: 0.55, blue: 0.95)
    case .beatSnap: Theme.positive
    case .punchIn: Theme.text
    }
  }
}
