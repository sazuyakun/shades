import ShadesCommands
import ShadesCore
import SwiftUI

/// The imported media as a thumbnail grid. Drop files here to import them.
struct MediaBrowser: View {

  // MARK: Internal

  @Binding var selection: Media.ID?
  @Binding var marks: [Media.ID: SourceMarks]
  @Binding var hover: MediaHover?

  let onImport: ([URL]) -> Void
  let onAppend: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      MediaBrowserHeader(
        count: editor.project.media.count,
        selection: selection,
        onAppend: onAppend,
      )
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
          ForEach(editor.project.media) { media in
            MediaTile(
              media: media,
              isSelected: media.id == selection,
              marks: marks[media.id],
            ) { time in
              hover = time.map { MediaHover(mediaID: media.id, time: $0) }
            }
            .onTapGesture { selection = media.id }
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
      }
      .overlay {
        if editor.project.media.isEmpty {
          Text(
            "Drop videos or music here\nor press ⌘I to import.\n"
              + "Hover a clip and press I / O\nto mark just a part."
          )
          .font(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(Theme.faintText)
        }
      }
    }
    .background(Theme.background)
    .dropDestination(for: URL.self) { urls, _ in
      onImport(urls)
      return true
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
