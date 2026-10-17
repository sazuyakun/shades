import SwiftUI

/// A 1-point divider in the hairline color, horizontal by default.
struct Hairline: View {
  var vertical = false

  var body: some View {
    Theme.hairline
      .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
  }
}
