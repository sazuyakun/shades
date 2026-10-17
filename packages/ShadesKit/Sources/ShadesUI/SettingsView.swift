import SwiftUI

/// The Settings window (⌘,): plugin folders and Claude's connection.
public struct SettingsView: View {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public var body: some View {
    TabView {
      Tab("Plugins", systemImage: "puzzlepiece.extension") {
        PluginFoldersSettings()
      }
      Tab("Claude", systemImage: "sparkle") {
        ClaudeSettings()
      }
    }
    .frame(width: 520, height: 340)
    .preferredColorScheme(.dark)
  }

}
