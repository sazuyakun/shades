import ShadesCommands
import SwiftUI

/// The bar above the timeline: the timeline's name as a capsule tab, and its length.
struct TimelineTitleBar: View {
  var body: some View {
    HStack {
      Text(editor.project.timeline.name)
        .font(.callout)
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(Theme.raised, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.strongHairline))
      Spacer()
      Text(Timecode.full(editor.project.timeline.duration.seconds))
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(Theme.faintText)
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
  }

  @Environment(Editor.self) private var editor
}
