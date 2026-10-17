import SwiftUI

/// One plugin folder in Settings: its path, shortened with `~`, and a note if it's missing.
struct PluginFolderRow: View {

  // MARK: Internal

  let url: URL

  var body: some View {
    HStack {
      Image(systemName: "folder")
        .foregroundStyle(.secondary)
      Text(displayPath)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      if !FileManager.default.fileExists(atPath: url.path) {
        Text("Not found")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: Private

  private var displayPath: String {
    let home = URL.homeDirectory.path
    return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
  }

}
