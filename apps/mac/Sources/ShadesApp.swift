import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesUI
import SwiftUI

/// The app's entry point: creates the editor, player and Claude server, and opens the window.
@main
struct ShadesApp: App {

  // MARK: Lifecycle

  init() {
    let editor = Editor()
    let player = Player()
    let server = MCPServer(editor: editor, player: player)
    do {
      try server.start()
    } catch {
      // why: the failure is logged where it happens; Shades still works without Claude. The
      // Claude setup sheet (M2) will show the connection state to the user.
    }
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
    }
    .defaultSize(width: 1440, height: 900)
  }

  // MARK: Private

  @State private var editor: Editor
  @State private var player: Player
  @State private var server: MCPServer

}
