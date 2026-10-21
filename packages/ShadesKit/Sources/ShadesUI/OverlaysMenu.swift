import ShadesCore
import ShadesEngine
import ShadesPlugins
import SwiftUI

/// Lays a plugin's overlay movie (light leak, dust) over the footage at the playhead, screened.
struct OverlaysMenu: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    Menu {
      if overlays.isEmpty {
        Text("No overlays yet: add a plugin with an overlays folder in Settings")
      }
      ForEach(overlays, id: \.self) { name in
        Button(name) { place(name) }
      }
    } label: {
      Label("Overlays", systemImage: "sun.haze")
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(CapsuleButtonStyle())
    .fixedSize()
    .help("Lay a plugin's overlay movie (light leak, dust) over the footage at the playhead")
  }

  // MARK: Private

  @Environment(PluginLibrary.self) private var plugins
  @Environment(Workspace.self) private var workspace
  @Environment(Player.self) private var player

  /// Every overlay, as `plugin/name`.
  private var overlays: [String] {
    plugins.plugins.flatMap { plugin in plugin.overlays.keys.map { "\(plugin.name)/\($0)" } }
      .sorted()
  }

  private func place(_ name: String) {
    let time = MediaTime(seconds: player.currentTime)
    Task {
      do {
        _ = try await workspace.addOverlay(
          named: name,
          at: time,
          duration: nil,
          blend: .screen,
          opacity: 1,
        )
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

}
