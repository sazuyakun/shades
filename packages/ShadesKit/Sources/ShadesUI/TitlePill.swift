import ShadesCommands
import SwiftUI

/// The centred title pill: the timeline's name and its format.
struct TitlePill: View {

  // MARK: Internal

  var body: some View {
    let format = editor.project.timeline.format
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 6)
        .fill(LinearGradient(
          colors: [.orange, .brown],
          startPoint: .topLeading,
          endPoint: .bottomTrailing,
        ))
        .frame(width: 20, height: 20)
      Text(editor.project.timeline.name)
        .fontWeight(.medium)
        .foregroundStyle(Theme.text)
      Text(verbatim: "\(format.width)×\(format.height) · \(format.framesPerSecond)p")
        .foregroundStyle(Theme.secondaryText)
    }
    .font(.callout)
    .padding(.leading, 6)
    .padding(.trailing, 14)
    .frame(height: 30)
    .background(Theme.raised, in: .capsule)
    .overlay(Capsule().strokeBorder(Theme.strongHairline))
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
