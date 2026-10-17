import AppKit
import Foundation
import Observation
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesMCP

// MARK: - Workspace

/// The app's one open project and the services working on it: the editor, the player and
/// Claude's server. It opens and creates projects, autosaves every change, and keeps snapshots
/// (every 10 minutes and before Claude edits).
@MainActor
@Observable
public final class Workspace {

  // MARK: Lifecycle

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let editor = Editor()
    let player = Player()
    self.editor = editor
    self.player = player
    server = MCPServer(editor: editor, player: player)
    wasRecovered = defaults.bool(forKey: Keys.isOpen) && !defaults.bool(forKey: Keys.quitCleanly)
    defaults.set(false, forKey: Keys.quitCleanly)
    server.beforeEdit = { [weak self] in self?.snapshotBeforeClaude() }
    server.projectHost = self
    server.start()
  }

  // MARK: Public

  /// How long after the last change the project is saved.
  public static let autosaveDelay = Duration.seconds(1)
  /// How often an automatic snapshot is kept.
  public static let snapshotInterval = Duration.seconds(600)
  /// Claude's calls closer together than this belong to one request, with one snapshot before.
  public static let claudeRequestGap = Duration.seconds(120)

  public let editor: Editor
  public let player: Player
  public let server: MCPServer

  /// The open project's package, or `nil` when none is open.
  public private(set) var documentURL: URL?
  /// A problem to show the user in plain words.
  public var errorMessage: String?
  /// Whether the last session ended without closing the project (a crash), shown once.
  public var wasRecovered: Bool
  /// The sheet showing over the editor, if any (menus open them).
  public var sheet: EditorSheet?

  /// The open project's name.
  public var projectName: String {
    documentURL?.deletingPathExtension().lastPathComponent ?? "Shades"
  }

  /// The project that was open last, if it still exists.
  public var lastProjectURL: URL? {
    guard
      let path = defaults.string(forKey: Keys.lastProject),
      FileManager.default.fileExists(atPath: path)
    else {
      return nil
    }
    return URL(filePath: path, directoryHint: .isDirectory)
  }

  /// Opens a project, saving the one that was open. Problems show in `errorMessage`.
  public func open(_ url: URL) async {
    do {
      try await openProject(at: url)
    } catch {
      errorMessage = error.errorDescription
    }
  }

  /// Creates a project in the library and opens it. Problems show in `errorMessage`.
  public func create(named name: String, format: VideoFormat) async {
    do {
      try await createProject(named: name, format: format)
    } catch {
      errorMessage = error.errorDescription
    }
  }

  /// Reopens the project that was open when Shades last quit or crashed. Runs once per launch.
  public func restoreLastProject() async {
    guard !didRestore else {
      return
    }
    didRestore = true
    if defaults.bool(forKey: Keys.isOpen), documentURL == nil, let last = lastProjectURL {
      await open(last)
    }
  }

  /// Saves everything before Shades quits, so the next launch reopens the project as it was.
  public func prepareToQuit() async {
    autosaveTask?.cancel()
    snapshotTask?.cancel()
    await save()
    await saveThumbnail()
    defaults.set(true, forKey: Keys.quitCleanly)
  }

  /// Saves and closes the open project.
  public func close() async {
    guard documentURL != nil else {
      return
    }
    snapshotTask?.cancel()
    await save()
    await saveThumbnail()
    player.pause()
    documentURL = nil
    defaults.set(false, forKey: Keys.isOpen)
  }

  /// Call after every project change: saves it shortly after the last change.
  public func projectDidChange() {
    autosaveTask?.cancel()
    autosaveTask = Task {
      try? await Task.sleep(for: Self.autosaveDelay) // why: cancelled means a newer change saves.
      guard !Task.isCancelled else {
        return
      }
      await save()
    }
  }

  /// Saves the project and where the user is in it, if anything changed.
  public func save() async {
    guard let documentURL else {
      return
    }
    let project = editor.project
    let session = Session(playhead: player.currentTime, selection: Array(editor.selection))
    do {
      try await ProjectFile.write(project, session: session, to: documentURL)
      savedProject = project
    } catch {
      errorMessage = error.errorDescription
    }
  }

  /// Keeps a named checkpoint of the project (⌘S).
  public func checkpoint(named name: String) async {
    await snapshot(label: name.isEmpty ? "Checkpoint" : name)
  }

  /// The project's snapshots, newest first.
  public func snapshots() async -> [Snapshot] {
    guard let documentURL else {
      return []
    }
    return await ProjectFile.snapshots(in: documentURL)
  }

  /// Brings back an earlier version as one undoable edit.
  public func revert(to snapshot: Snapshot) async {
    do {
      let project = try await ProjectFile.read(snapshot)
      try editor.perform(RestoreProject(project: project))
    } catch let error as DocumentError {
      errorMessage = error.errorDescription
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: Fileprivate

  fileprivate enum Keys {
    static let lastProject = "lastProject"
    static let isOpen = "projectIsOpen"
    static let quitCleanly = "quitCleanly"
  }

  // MARK: Private

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var savedProject: Project?
  /// The project as of the last snapshot, so unchanged projects aren't snapshotted again.
  @ObservationIgnored private var snapshotBase: Project?
  @ObservationIgnored private var autosaveTask: Task<Void, Never>?
  @ObservationIgnored private var snapshotTask: Task<Void, Never>?
  @ObservationIgnored private var didRestore = false
  @ObservationIgnored private var lastClaudeSnapshot: ContinuousClock.Instant?

  private func snapshotBeforeClaude() {
    let now = ContinuousClock.now
    if let last = lastClaudeSnapshot, now - last < Self.claudeRequestGap {
      return
    }
    lastClaudeSnapshot = now
    Task { await snapshot(label: "Before Claude") }
  }

  /// Saves a snapshot unless nothing changed since the last one.
  private func snapshot(label: String) async {
    guard let documentURL, editor.project != snapshotBase else {
      return
    }
    let project = editor.project
    snapshotBase = project
    do {
      try await ProjectFile.snapshot(project, label: label, in: documentURL)
    } catch {
      errorMessage = error.errorDescription
    }
  }

  private func startSnapshotTimer() {
    snapshotTask?.cancel()
    snapshotTask = Task {
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.snapshotInterval) // why: cancelled ends the loop.
        guard !Task.isCancelled else {
          return
        }
        await snapshot(label: "Auto")
        await saveThumbnail()
      }
    }
  }

  /// Saves a frame at the playhead for the welcome window. A failure only costs the picture.
  private func saveThumbnail() async {
    guard let documentURL, editor.project.timeline.duration > .zero else {
      return
    }
    let seconds = min(player.currentTime, editor.project.timeline.duration.seconds - 0.05)
    // why: no thumbnail is a fine outcome; the welcome window shows a placeholder.
    guard
      let png = try? await FrameRenderer.png(
        of: editor.project,
        atSeconds: max(seconds, 0),
        maxSide: 480,
      )
    else {
      return
    }
    try? await ProjectFile.writeThumbnail(png, to: documentURL) // why: same as above.
  }

}

// MARK: ProjectHost

extension Workspace: ProjectHost {
  public func openProject(at url: URL) async throws(DocumentError) {
    let (project, session) = try await ProjectFile.read(at: url)
    await close()
    // why: the editor view loads playback when the project changes; it starts at the cue.
    player.cue(toSeconds: session.playhead)
    editor.load(project)
    editor.selection = Set(session.selection)
    server.activity.clear()
    documentURL = url
    savedProject = project
    snapshotBase = project
    defaults.set(url.path, forKey: Keys.lastProject)
    defaults.set(true, forKey: Keys.isOpen)
    startSnapshotTimer()
  }

  public func createProject(named name: String, format: VideoFormat) async throws(DocumentError) {
    let url = try await ProjectLibrary.create(named: name, format: format)
    try await openProject(at: url)
  }
}
