import SwiftUI

/// The playhead: a thin white line with a small rounded handle on top.
struct Playhead: View {
  var body: some View {
    VStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 3)
        .fill(Theme.text)
        .frame(width: 12, height: 12)
      Rectangle()
        .fill(Theme.text)
        .frame(width: 1.5)
    }
    .frame(width: 12)
  }
}
