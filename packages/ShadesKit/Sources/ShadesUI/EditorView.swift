import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMedia
import SwiftUI

/// The main window: media browser, viewer and inspector on top, the timeline below.
public struct EditorView: View {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public var body: some View {
    VSplitView {
      HSplitView {
        MediaBrowser(
          selection: $selection,
          onImport: { urls in Task { await importMedia(urls) } },
          onAppend: appendClip,
        )
        .frame(minWidth: 220, idealWidth: 300)
        ViewerPane()
          .frame(minWidth: 400)
        InspectorPane(selection: selection)
          .frame(minWidth: 220, idealWidth: 280)
      }
      .frame(minHeight: 320)
      TimelinePane()
        .frame(minHeight: 200, idealHeight: 280)
    }
    .background(Theme.window)
    .preferredColorScheme(.dark)
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button("Import", systemImage: "square.and.arrow.down") { isImporting = true }
          .keyboardShortcut("i")
          .help("Import media (⌘I)")
      }
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [.movie],
      allowsMultipleSelection: true,
    ) { result in
      if case .success(let urls) = result {
        Task { await importMedia(urls) }
      }
    }
    .task(id: editor.project) {
      do {
        try await player.load(editor.project)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
    .alert(
      "Something went wrong",
      isPresented: Binding(get: { errorMessage != nil }, set: {
        if !$0 {
          errorMessage = nil
        }
      }),
      actions: { Button("OK") { } },
      message: { Text(errorMessage ?? "") },
    )
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var selection: Media.ID?
  @State private var isImporting = false
  @State private var errorMessage: String?

  private func importMedia(_ urls: [URL]) async {
    for url in urls {
      do {
        let media = try await MediaLoader.load(url)
        try editor.perform(AddMedia(media: media))
        selection = media.id
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func appendClip(_ mediaID: Media.ID) {
    do {
      try editor.perform(AppendClip(mediaID: mediaID))
    } catch {
      errorMessage = error.localizedDescription
    }
  }

}
