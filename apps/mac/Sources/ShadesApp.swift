import ShadesUI
import SwiftUI

/// The app's entry point: the workspace (open project, player, Claude's server), the editor and
/// welcome windows, and Settings. Reopens the last project at launch and saves it at quit.
@main
struct ShadesApp: App {

  // MARK: Internal

  var body: some Scene {
    Window("Shades", id: WindowID.editor) {
      EditorView()
        .environment(workspace)
        .environment(workspace.editor)
        .environment(workspace.player)
        .environment(workspace.server)
        .environment(workspace.plugins)
        .task { await workspace.restoreLastProject() }
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1440, height: 900)
    .defaultLaunchBehavior(hasLastProject ? .presented : .suppressed)
    .commands { FileMenu(workspace: workspace) }

    Window("Welcome to Shades", id: WindowID.welcome) {
      WelcomeView()
        .environment(workspace)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .defaultLaunchBehavior(hasLastProject ? .suppressed : .presented)

    Settings {
      SettingsView()
        .environment(workspace.server)
        .environment(workspace.pluginFolders)
        .environment(workspace.plugins)
    }
  }

  // MARK: Private

  @NSApplicationDelegateAdaptor private var delegate: AppDelegate

  private var workspace: Workspace {
    delegate.workspace
  }

  private var hasLastProject: Bool {
    workspace.lastProjectURL != nil
  }

}
