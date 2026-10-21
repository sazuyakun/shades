import ShadesCore
import ShadesEngine
import ShadesPlugins
import SwiftUI

/// Places a plugin's sound effect (whooshes, pops, risers) at the playhead on a free audio track.
struct SoundsMenu: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    Menu {
      if sounds.isEmpty {
        Text("No sounds yet: add a plugin folder in Settings")
      }
      ForEach(sounds, id: \.self) { name in
        Button(name) { place(name) }
      }
    } label: {
      Label("Sounds", systemImage: "speaker.wave.2")
    }
    .menuStyle(.button)
    .menuIndicator(.hidden)
    .buttonStyle(CapsuleButtonStyle())
    .fixedSize()
    .help("Place a plugin's sound effect at the playhead")
  }

  // MARK: Private

  @Environment(PluginLibrary.self) private var plugins
  @Environment(Workspace.self) private var workspace
  @Environment(Player.self) private var player

  /// Every sound, as `plugin/name`.
  private var sounds: [String] {
    plugins.plugins.flatMap { plugin in plugin.sounds.keys.map { "\(plugin.name)/\($0)" } }
      .sorted()
  }

  private func place(_ name: String) {
    let time = MediaTime(seconds: player.currentTime)
    Task {
      do {
        _ = try await workspace.addSound(named: name, at: time, volume: nil)
      } catch {
        onError(error.localizedDescription)
      }
    }
  }

}
