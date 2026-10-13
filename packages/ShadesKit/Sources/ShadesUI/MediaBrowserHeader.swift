import ShadesCore
import SwiftUI

/// The media browser's title bar, with the Append button (R).
struct MediaBrowserHeader: View {
  let selection: Media.ID?
  let onAppend: (Media.ID) -> Void

  var body: some View {
    HStack {
      Text("All Clips").fontWeight(.semibold)
      Spacer()
      Button("Append") {
        if let selection {
          onAppend(selection)
        }
      }
      .keyboardShortcut("r", modifiers: [])
      .disabled(selection == nil)
      .help("Append the selected clip to the end of the timeline (R)")
    }
    .font(.caption)
    .padding(.horizontal, 10)
    .frame(height: 30)
  }
}
