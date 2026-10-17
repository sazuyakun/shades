import SwiftUI

/// Glaze-style capsule that groups related buttons in the title bar.
struct CapsuleGroup<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    HStack(spacing: 2) {
      content
    }
    .padding(3)
    .background(Theme.raised, in: .capsule)
    .overlay(Capsule().strokeBorder(Theme.strongHairline))
  }
}
