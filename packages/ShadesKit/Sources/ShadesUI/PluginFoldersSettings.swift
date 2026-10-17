import ShadesPlugins
import SwiftUI

/// Settings › Plugins: the folders plugins load from, top first. Add, remove and drag to reorder.
struct PluginFoldersSettings: View {

  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      List(selection: $selection) {
        ForEach(folders.urls, id: \.self) { url in
          PluginFolderRow(url: url)
        }
        .onMove { folders.move(fromOffsets: $0, toOffset: $1) }
      }
      .listStyle(.bordered)
      HStack(spacing: 0) {
        Button("Add Folder", systemImage: "plus") { isChoosing = true }
        Button("Remove Folder", systemImage: "minus") { removeSelection() }
          .disabled(selection == nil)
        Spacer()
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .controlSize(.large)
      Text("Shades loads plugins from these folders, top first. Drag to reorder.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .fileImporter(isPresented: $isChoosing, allowedContentTypes: [.folder]) { result in
      if case .success(let url) = result {
        folders.add(url)
      }
    }
  }

  // MARK: Private

  @Environment(PluginFolders.self) private var folders
  @State private var selection: URL?
  @State private var isChoosing = false

  private func removeSelection() {
    guard let selection, let index = folders.urls.firstIndex(of: selection) else {
      return
    }
    folders.remove(atOffsets: [index])
    self.selection = nil
  }

}
