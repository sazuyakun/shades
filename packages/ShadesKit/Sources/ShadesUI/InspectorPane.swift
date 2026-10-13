import ShadesCommands
import ShadesCore
import SwiftUI

/// Details of the selected media, under Video / Color / Audio / Info tabs.
struct InspectorPane: View {

  // MARK: Internal

  let selection: Media.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Inspector", selection: $tab) {
        ForEach(InspectorTab.allCases, id: \.self) { Text($0.rawValue) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      if tab == .info, let media = selection.flatMap(editor.project.media(withID:)) {
        MediaInfo(media: media)
      } else {
        Text(tab == .info ? "Select a clip to see its details." : "Nothing to adjust yet.")
          .foregroundStyle(Theme.secondaryText)
      }
      Spacer()
    }
    .font(.callout)
    .padding(12)
    .background(Theme.panel)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @State private var tab = InspectorTab.info

}
