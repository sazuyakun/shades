import ShadesCommands
import SwiftUI

/// The bar above the timeline: the sequence name and its length.
struct TimelineTitleBar: View {
  var body: some View {
    HStack(spacing: 6) {
      Text(editor.project.timeline.name)
      Text(Timecode.full(editor.project.timeline.duration.seconds))
        .foregroundStyle(Theme.secondaryText)
        .monospacedDigit()
    }
    .font(.caption)
    .frame(maxWidth: .infinity)
    .frame(height: 30)
    .background(Theme.panel)
  }

  @Environment(Editor.self) private var editor
}
