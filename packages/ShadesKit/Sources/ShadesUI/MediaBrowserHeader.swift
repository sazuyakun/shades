import ShadesCore
import SwiftUI

/// The media browser's header: the MEDIA label, clip count and the Append button (R).
struct MediaBrowserHeader: View {
  let count: Int
  let selection: Media.ID?
  let onAppend: (Media.ID) -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      SectionLabel(title: "Media", detail: count == 1 ? "1 clip" : "\(count) clips")
      Button("Append") {
        if let selection {
          onAppend(selection)
        }
      }
      .buttonStyle(CapsuleButtonStyle())
      .disabled(selection == nil)
      .help("Append the selected clip to the end of the timeline (R)")
      .padding(.trailing, 8)
    }
  }
}
