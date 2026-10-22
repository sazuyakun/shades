import Foundation
import ShadesCore
import ShadesDocument
import ShadesUI
import Testing

/// Sets up the app's workspace for a scripted Claude session: a new 1440×1080 project open and
/// Claude's server ready.
@MainActor
enum ScenarioWorkspace {

  /// A workspace serving Claude on `port`, loading plugins only from `plugins` (none by default)
  /// so the user's own plugins never leak into a test.
  static func open(port: UInt16, plugins: URL? = nil) async throws -> Workspace {
    let package = FileManager.default.temporaryDirectory.appending(
      path: "\(UUID().uuidString).shades",
      directoryHint: .isDirectory,
    )
    try await ProjectFile.write(
      Project(timeline: Timeline(format: .half)),
      session: Session(),
      to: package,
    )
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: port,
    )
    workspace.pluginFolders.remove(atOffsets: IndexSet(workspace.pluginFolders.urls.indices))
    if let plugins {
      workspace.pluginFolders.add(plugins)
    }
    await workspace.plugins.reload()
    try await workspace.openProject(at: package)
    for _ in 0 ..< 200 where workspace.server.status == .starting {
      try await Task.sleep(for: .milliseconds(10))
    }
    try #require(workspace.server.status == .ready, "Claude's server isn't listening on \(port)")
    return workspace
  }

}
