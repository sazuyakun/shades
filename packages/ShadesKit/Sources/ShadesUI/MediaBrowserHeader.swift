import ShadesCore
import SwiftUI

/// The media browser's header: the MEDIA label, clip count and the Append button (R).
struct MediaBrowserHeader: View {
  let count: Int
  let selection: Media.ID?
  let onAppend: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      SectionLabel(title: "Media", detail: count == 1 ? "1 clip" : "\(count) clips")
      Button("Append", action: onAppend)
        .buttonStyle(CapsuleButtonStyle())
        .disabled(selection == nil)
        .help("Append the selected clip (or its I / O part) to the end of the timeline (R)")
        .padding(.trailing, 8)
    }
  }
}
