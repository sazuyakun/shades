import SwiftUI

/// A small note after a crash: the project reopened exactly where it was. Fades on its own.
struct RecoveredNote: View {
  let onDone: () -> Void

  var body: some View {
    Text("Recovered: Shades reopened your project where you left off.")
      .font(.callout)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Theme.raised, in: .capsule)
      .overlay { Capsule().strokeBorder(Theme.strongHairline) }
      .task {
        try? await Task.sleep(for: .seconds(4)) // why: cancelled means the window closed.
        onDone()
      }
  }
}
