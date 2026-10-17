import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesPlugins
import ShadesUI
import SwiftUI

/// The app's entry point: creates the editor, player, Claude server and plugin folders, and
/// opens the window and Settings.
@main
struct ShadesApp: App {

  // MARK: Lifecycle

  init() {
    let editor = Editor()
    let player = Player()
    let server = MCPServer(editor: editor, player: player)
    server.start()
    _editor = State(initialValue: editor)
    _player = State(initialValue: player)
    _server = State(initialValue: server)
  }

  // MARK: Internal

  var body: some Scene {
    WindowGroup {
      EditorView()
        .environment(editor)
        .environment(player)
        .environment(server)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1440, height: 900)
    Settings {
      SettingsView()
        .environment(server)
        .environment(pluginFolders)
    }
  }

  // MARK: Private

  @State private var editor: Editor
  @State private var player: Player
  @State private var server: MCPServer
  @State private var pluginFolders = PluginFolders()

}
