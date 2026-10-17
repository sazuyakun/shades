import AppKit
import Foundation
import Observation
import ShadesAudio
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesMCP
import ShadesMedia

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
    let jobs = JobQueue()
    self.editor = editor
    self.player = player
    self.jobs = jobs
    server = MCPServer(editor: editor, player: player, jobs: jobs)
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
  /// Background work for this project: proxies, transcripts, analysis.
  public let jobs: JobQueue
  /// What's been worked out about each media file: transcripts, speech, beats.
  public let analysis = AnalysisLibrary()

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
    queuedProxies.removeAll()
    player.proxies = [:]
    analysis.clear()
    documentURL = nil
    defaults.set(false, forKey: Keys.isOpen)
  }

  /// Call after every project change: saves it shortly after the last change, and makes
  /// proxies for newly imported heavy footage.
  public func projectDidChange() {
    makeMissingProxies()
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
  @ObservationIgnored private var queuedProxies = Set<Media.ID>()
  @ObservationIgnored private var lastClaudeSnapshot: ContinuousClock.Instant?

  /// Queues a proxy for every heavy file that has none yet; playback switches to each as it's
  /// ready.
  private func makeMissingProxies() {
    guard let documentURL else {
      return
    }
    let cache = documentURL.appending(path: "cache")
    for media in editor.project.media
      where ProxyMaker.needsProxy(media) && player.proxies[media.id] == nil
    {
      guard !queuedProxies.contains(media.id) else {
        continue
      }
      queuedProxies.insert(media.id)
      let url = ProxyMaker.proxyURL(for: media, in: cache)
      jobs.enqueue("Making an editing copy of \(media.name)") { [weak self] _ throws(JobError) in
        if !FileManager.default.fileExists(atPath: url.path) {
          do throws(MediaError) {
            try await ProxyMaker.makeProxy(of: media, at: url)
          } catch {
            throw .failed(error.errorDescription ?? "The editing copy couldn't be made.")
          }
        }
        await self?.useProxy(url, for: media.id, in: documentURL)
      }
    }
  }

  /// Switches playback to a finished proxy, if its project is still open.
  private func useProxy(_ url: URL, for mediaID: Media.ID, in project: URL) async {
    queuedProxies.remove(mediaID)
    guard project == documentURL else {
      return
    }
    player.proxies[mediaID] = url
    try? await player.load(editor.project) // why: the editor shows playback errors.
  }

  /// Media on the timeline that plays sound, or just `ids` when given.
  private func soundMedia(_ ids: [Media.ID]?) -> [Media] {
    let used = Set(editor.project.timeline.allClips.compactMap(\.mediaID))
    return editor.project.media.filter { media in
      media.hasAudio && (ids.map { $0.contains(media.id) } ?? used.contains(media.id))
    }
  }

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

  // MARK: Public

  public func openProject(at url: URL) async throws(DocumentError) {
    let (project, session) = try await ProjectFile.read(at: url)
    await close()
    // why: the editor view loads playback when the project changes; it starts at the cue.
    player.cue(toSeconds: session.playhead)
    await analysis.load(from: url)
    editor.load(project)
    editor.selection = Set(session.selection)
    server.activity.clear()
    documentURL = url
    savedProject = project
    snapshotBase = project
    defaults.set(url.path, forKey: Keys.lastProject)
    defaults.set(true, forKey: Keys.isOpen)
    startSnapshotTimer()
    makeMissingProxies()
  }

  public func createProject(named name: String, format: VideoFormat) async throws(DocumentError) {
    let url = try await ProjectLibrary.create(named: name, format: format)
    try await openProject(at: url)
  }

  /// Queues transcripts for `mediaIDs` (default: sound on the timeline not yet transcribed) and
  /// returns what was queued.
  public func transcribe(
    _ mediaIDs: [Media.ID]?,
    model: TranscriptionModel,
    language: String?,
  ) -> [String] {
    guard let package = documentURL else {
      return []
    }
    let wanted = soundMedia(mediaIDs)
      .filter { mediaIDs != nil || analysis.analyses[$0.id]?.transcript == nil }
    return wanted.map { media in
      let title = "Transcribing \(media.name)"
      jobs.enqueue(title) { [weak self] progress throws(JobError) in
        let transcript: Transcript
        do throws(CaptionsError) {
          transcript = try await Transcriber.transcribe(
            media.url,
            model: model,
            language: language,
            progress: progress,
          )
        } catch {
          throw error == .cancelled
            ? .cancelled
            : .failed(error.errorDescription ?? "The transcript couldn't be made.")
        }
        try await self?.store(media.id, in: package) { $0.transcript = transcript }
      }
      return title
    }
  }

  /// Queues speech-activity and beat detection for `mediaIDs` (default: sound on the timeline
  /// not yet analysed) and returns what was queued.
  public func analyzeAudio(_ mediaIDs: [Media.ID]?) -> [String] {
    guard let package = documentURL else {
      return []
    }
    let wanted = soundMedia(mediaIDs)
      .filter { mediaIDs != nil || analysis.analyses[$0.id]?.speech == nil }
    return wanted.map { media in
      let title = "Analysing the sound of \(media.name)"
      jobs.enqueue(title) { [weak self] progress throws(JobError) in
        let speech: [TimeRange]
        let beats: BeatGrid
        do throws(AudioError) {
          speech = try await SpeechActivity.detect(in: media.url)
          progress(0.5)
          beats = try await BeatDetector.detect(in: media.url)
        } catch {
          throw .failed(error.errorDescription ?? "The sound couldn't be analysed.")
        }
        try await self?.store(media.id, in: package) { analysis in
          analysis.speech = speech
          analysis.beats = beats
        }
      }
      return title
    }
  }

  /// Adds captions for what's said on the timeline (in `range`, or everywhere) as text clips on
  /// a text track, in one undo step. Returns how many were added.
  public func addCaptions(in range: TimeRange?) throws(CommandError) -> Int {
    let words = editor.project.timeline.spokenWords(transcripts: analysis.transcripts)
      .filter { word in range.map { $0.start <= word.start && word.start < $0.end } ?? true }
    guard !words.isEmpty else {
      throw .invalidArguments("there are no transcribed words here; transcribe the clips first")
    }
    let lines = CaptionLayout.lines(for: words)
    try editor.perform(
      lines.map { AddText(text: $0.text, at: $0.start, duration: $0.end - $0.start) },
      title: "Add Captions",
    )
    return lines.count
  }

  // MARK: Private

  /// Saves an analysis result, if its project is still the open one.
  private func store(
    _ mediaID: Media.ID,
    in package: URL,
    change: (inout MediaAnalysis) -> Void,
  ) async throws(JobError) {
    guard package == documentURL else {
      throw .cancelled
    }
    do {
      try await analysis.update(mediaID, in: package, change: change)
    } catch {
      throw .failed(error.errorDescription ?? "The result couldn't be saved.")
    }
  }

}
