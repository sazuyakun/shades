import ShadesCommands
import ShadesCore
import SwiftUI

/// Details of the selected media, under Video / Color / Audio / Info tabs.
struct InspectorPane: View {

  // MARK: Internal

  let selection: Media.ID?

  var body: some View {
    let media = selection.flatMap(editor.project.media(withID:))
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: media?.name ?? "Inspector")
      CapsuleGroup {
        ForEach(InspectorTab.allCases, id: \.self) { item in
          Button(item.rawValue) { tab = item }
            .buttonStyle(CapsuleButtonStyle(isOn: tab == item))
        }
      }
      .padding(.horizontal, 14)
      .padding(.bottom, 10)
      Hairline()
      Group {
        if tab == .info, let media {
          MediaInfo(media: media, framesPerSecond: editor.project.timeline.format.framesPerSecond)
        } else {
          Text(tab == .info ? "Select a clip to see its details." : "Nothing to adjust yet.")
            .foregroundStyle(Theme.faintText)
        }
      }
      .font(.callout)
      .padding(14)
      Spacer()
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @State private var tab = InspectorTab.info

}
