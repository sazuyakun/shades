import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMedia
import SwiftUI

/// The main window: the title bar, then media browser, viewer and side pane on top, with the
/// timeline below. Panes are separated by hairlines on one warm near-black.
public struct EditorView: View {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public var body: some View {
    VStack(spacing: 0) {
      TitleBar(sidePane: $sidePane, onImport: { isImporting = true })
      Hairline()
      VSplitView {
        HSplitView {
          MediaBrowser(
            selection: $selection,
            onImport: { urls in Task { await importMedia(urls) } },
            onAppend: appendClip,
          )
          .frame(minWidth: 220, idealWidth: 280, maxWidth: 420)
          ViewerPane()
            .frame(minWidth: 400, maxWidth: .infinity)
            .layoutPriority(1)
          Group {
            switch sidePane {
            case .inspector: InspectorPane(selection: selection)
            case .history: HistoryPane()
            }
          }
          .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
        }
        .frame(minHeight: 320, idealHeight: 560)
        TimelinePane()
          .frame(minHeight: 200, idealHeight: 300)
      }
    }
    .ignoresSafeArea(.container, edges: .top)
    .background(Theme.background)
    .foregroundStyle(Theme.text)
    .preferredColorScheme(.dark)
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [.movie],
      allowsMultipleSelection: true,
    ) { result in
      if case .success(let urls) = result {
        Task { await importMedia(urls) }
      }
    }
    .onChange(of: editor.project) { workspace.projectDidChange() }
    .onDisappear {
      Task { await workspace.close() }
      openWindow(id: WindowID.welcome)
    }
    .overlay(alignment: .top) {
      if workspace.wasRecovered {
        RecoveredNote { workspace.wasRecovered = false }
          .padding(.top, 56)
      }
    }
    .sheet(item: Binding(get: { workspace.sheet }, set: { workspace.sheet = $0 })) { sheet in
      switch sheet {
      case .checkpoint: CheckpointSheet()
      case .revert: RevertSheet()
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
      isPresented: Binding(get: { errorMessage != nil || workspace.errorMessage != nil }, set: {
        if !$0 {
          errorMessage = nil
          workspace.errorMessage = nil
        }
      }),
      actions: { Button("OK") { } },
      message: { Text(errorMessage ?? workspace.errorMessage ?? "") },
    )
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(Workspace.self) private var workspace
  @Environment(\.openWindow) private var openWindow
  @State private var selection: Media.ID?
  @State private var sidePane = SidePane.inspector
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
