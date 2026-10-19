import ShadesPlugins
import SwiftUI

/// One loaded plugin: its name, what it offers, and what's wrong with its manifest if anything.
struct LoadedPluginRow: View {

  // MARK: Internal

  let plugin: Plugin

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(plugin.name).font(.body.weight(.semibold))
      Text(contents).font(.callout).foregroundStyle(.secondary)
      if let problem = plugin.problem {
        Text(problem).font(.callout).foregroundStyle(Theme.negative)
      }
    }
  }

  // MARK: Private

  private var contents: String {
    let counts = [
      (plugin.styles.count, "style"),
      (plugin.templates.count, "template"),
      (plugin.stickers.count, "sticker"),
      (plugin.sounds.count, "sound"),
      (plugin.fonts.count, "font"),
    ].filter { $0.0 > 0 }
    return counts.isEmpty
      ? "Empty"
      : counts.lazy.map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }.joined(separator: " · ")
  }

}
