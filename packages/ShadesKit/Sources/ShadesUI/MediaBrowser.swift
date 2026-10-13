import ShadesCommands
import ShadesCore
import SwiftUI

/// The imported media as a thumbnail grid. Drop files here to import them.
struct MediaBrowser: View {

  // MARK: Internal

  @Binding var selection: Media.ID?

  let onImport: ([URL]) -> Void
  let onAppend: (Media.ID) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      MediaBrowserHeader(selection: selection, onAppend: onAppend)
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
          ForEach(editor.project.media) { media in
            MediaTile(media: media, isSelected: media.id == selection)
              .onTapGesture { selection = media.id }
          }
        }
        .padding(10)
      }
      .overlay {
        if editor.project.media.isEmpty {
          Text("Drop videos here\nor press ⌘I to import")
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.secondaryText)
        }
      }
    }
    .background(Theme.panel)
    .dropDestination(for: URL.self) { urls, _ in
      onImport(urls)
      return true
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
