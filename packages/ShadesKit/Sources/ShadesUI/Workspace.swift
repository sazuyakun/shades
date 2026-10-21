import AppKit
import Foundation
import Observation
import ShadesAudio
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesExport
import ShadesMatting
import ShadesMCP
import ShadesMedia
import ShadesPlugins
import ShadesPolish

// MARK: - Workspace

/// The app's one open project and the services working on it: the editor, the player and
/// Claude's server. It opens and creates projects, autosaves every change, and keeps snapshots
/// (every 10 minutes and before Claude edits).
@MainActor
@Observable
public final class Workspace {

  // MARK: Lifecycle

  /// `port` is where Claude connects; tests pass 0 for any free port.
  public init(defaults: UserDefaults = .standard, port: UInt16 = MCPServer.defaultPort) {
    self.defaults = defaults
    let editor = Editor()
    let player = Player()
    let jobs = JobQueue()
    self.editor = editor
    self.player = player
    self.jobs = jobs
    pluginFolders = PluginFolders(defaults: defaults)
    plugins = PluginLibrary(folders: pluginFolders)
    server = MCPServer(editor: editor, player: player, jobs: jobs, port: port)
    wasRecovered = defaults.bool(forKey: Keys.isOpen) && !defaults.bool(forKey: Keys.quitCleanly)
    defaults.set(false, forKey: Keys.quitCleanly)
    server.beforeEdit = { [weak self] in self?.snapshotBeforeClaude() }
    server.projectHost = self
    server.start()
    Task { await plugins.start() }
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
  /// Where plugins are loaded from (Settings → Plugins).
  public let pluginFolders: PluginFolders
  /// The loaded plugins: styles, templates, stickers, sounds and fonts.
  public let plugins: PluginLibrary

  /// The open project's package, or `nil` when none is open.
  public private(set) var documentURL: URL?
  /// A problem to show the user in plain words.
  public var errorMessage: String?
  /// Whether the last session ended without closing the project (a crash), shown once.
  public var wasRecovered: Bool
  /// The sheet showing over the editor, if any (menus open them).
  public var sheet: EditorSheet?
  /// Polish proposed and waiting for review, if any.
  public private(set) var polishPlan: PolishPlan?

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
    queuedWaveforms.removeAll()
    player.proxies = [:]
    player.mattes = [:]
    player.cleanSound = [:]
    analysis.clear()
    documentURL = nil
    defaults.set(false, forKey: Keys.isOpen)
  }

  /// Call after every project change: saves it shortly after the last change, and makes
  /// proxies for newly imported heavy footage.
  public func projectDidChange() {
    makeMissingProxies()
    makeMissingWaveforms()
    if polishPlan != nil, editor.project != polishBase {
      polishPlan = nil
    }
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
    let playhead = player.currentTime.isFinite ? player.currentTime : 0
    let session = Session(playhead: playhead, selection: Array(editor.selection))
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
  /// The project as it was when the Polish plan was made; any other change discards the plan.
  @ObservationIgnored private var polishBase: Project?
  @ObservationIgnored private var queuedProxies = Set<Media.ID>()
  @ObservationIgnored private var queuedWaveforms = Set<Media.ID>()
  @ObservationIgnored private let notifier = ExportNotifier()
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
      guard !FileManager.default.fileExists(atPath: url.path) else {
        Task { await useProxy(url, for: media.id, in: documentURL) }
        continue
      }
      jobs.enqueue("Making an editing copy of \(media.name)") { [weak self] _ throws(JobError) in
        do throws(MediaError) {
          try await ProxyMaker.makeProxy(of: media, at: url)
        } catch {
          throw .failed(error.errorDescription ?? "The editing copy couldn't be made.")
        }
        await self?.useProxy(url, for: media.id, in: documentURL)
      }
    }
  }

  /// Queues a waveform for every sound file that has none yet, for the timeline to draw.
  private func makeMissingWaveforms() {
    guard let package = documentURL else {
      return
    }
    for media in editor.project.media
      where media.hasAudio && analysis.analyses[media.id]?.waveform == nil
      && !queuedWaveforms.contains(media.id)
    {
      queuedWaveforms.insert(media.id)
      jobs.enqueue("Drawing the sound of \(media.name)") { [weak self] _ throws(JobError) in
        let peaks: [Float]
        do throws(AudioError) {
          peaks = try await Waveform.peaks(in: media.url)
        } catch {
          throw .failed(error.errorDescription ?? "The sound couldn't be read.")
        }
        try await self?.store(media.id, in: package) { $0.waveform = peaks }
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
    player.mattes = analysis.analyses.compactMapValues { record in
      record.matte.map { url.appending(path: "cache/mattes/\($0)") }
    }
    player.cleanSound = analysis.analyses.compactMapValues { record in
      record.cleanSound.map { url.appending(path: "cache/sound/\($0)") }
    }
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
    makeMissingWaveforms()
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
  /// a text track, in one undo step, revealed and styled as asked. Returns how many were added.
  public func addCaptions(
    in range: TimeRange?,
    reveal: TextReveal,
    style: TextStyle?,
  ) throws(CommandError) -> Int {
    let words = editor.project.timeline.spokenWords(transcripts: analysis.transcripts)
      .filter { word in range.map { $0.start <= word.start && word.start < $0.end } ?? true }
    guard !words.isEmpty else {
      throw .invalidArguments("there are no transcribed words here; transcribe the clips first")
    }
    let lines = CaptionLayout.lines(for: words)
    try editor.perform(AddCaptions(
      lines: lines.map { line in
        AddCaptions.Line(
          text: line.text,
          start: line.start,
          end: line.end,
          words: line.words.map { word in
            TimedWord(text: word.text, start: word.start - line.start, end: word.end - line.start)
          },
        )
      },
      style: style,
      reveal: reveal,
    ))
    return lines.count
  }

  /// Proposes Polish for `range` on `track` and keeps the plan for review.
  @discardableResult
  public func proposePolish(
    in range: TimeRange,
    track: String?,
    options: PolishOptions,
  ) -> PolishPlan {
    let plan = PolishPlanner.plan(
      editor.project.timeline,
      analyses: analysis.analyses,
      range: range,
      track: track,
      options: options,
    )
    polishPlan = plan
    polishBase = editor.project
    return plan
  }

  /// Switches plan items on or off: those in `ids`, or all of `kind`.
  public func setPolish(_ isEnabled: Bool, ids: Set<UUID>? = nil, kind: PolishKind? = nil) {
    guard var plan = polishPlan else {
      return
    }
    for index in plan.items.indices
      where ids?.contains(plan.items[index].id) ?? (plan.items[index].kind == kind)
    {
      plan.items[index].isEnabled = isEnabled
    }
    polishPlan = plan
  }

  /// Applies the plan's switched-on items as one undo step (only `ids` or `kinds` when given),
  /// then clears it. Returns what was done.
  public func applyPolish(ids: Set<UUID>?, kinds: Set<PolishKind>?) throws(CommandError) -> String {
    guard var plan = polishPlan else {
      throw .invalidArguments("there's no Polish plan; propose one first")
    }
    for index in plan.items.indices {
      let item = plan.items[index]
      if let ids {
        plan.items[index].isEnabled = ids.contains(item.id)
      } else if let kinds {
        plan.items[index].isEnabled = item.isEnabled && kinds.contains(item.kind)
      }
    }
    let summary = PolishKind.allCases.compactMap { kind in
      let count = plan.enabledCount(of: kind)
      return count > 0 ? "\(kind.title.lowercased()): \(count)" : nil
    }
    polishPlan = nil
    try editor.perform(ApplyPolish(plan: plan))
    return summary.isEmpty
      ? "Nothing was switched on, so nothing changed."
      : "Polished — " + summary.joined(separator: ", ") + "."
  }

  /// Throws the plan away without changing anything.
  public func discardPolish() {
    polishPlan = nil
  }

  /// Queues cut-outs for `mediaIDs` (default: video on the timeline without one) and returns
  /// what was queued.
  public func makeCutouts(_ mediaIDs: [Media.ID]?, engine: MatteEngine) -> [String] {
    guard let package = documentURL else {
      return []
    }
    let used = Set(editor.project.timeline.allClips.compactMap(\.mediaID))
    let wanted = editor.project.media.filter { media in
      media
        .hasVideo && !media.isStill &&
        (mediaIDs
          .map { $0.contains(media.id) } ??
          (used.contains(media.id) && analysis.analyses[media.id]?.matte == nil))
    }
    return wanted.map { media in
      let title = "Cutting out the subject of \(media.name)"
      let file = "\(media.id.uuidString)-\(engine.rawValue).mov"
      let url = package.appending(path: "cache/mattes/\(file)")
      jobs.enqueue(title) { [weak self] progress throws(JobError) in
        let path: [SubjectPoint]
        do throws(MattingError) {
          try await MatteMaker
            .make(from: media.url, to: url, engine: engine) { progress($0 * 0.95) }
          path = try await MatteMaker.subjectPath(of: url)
        } catch {
          throw error == .cancelled
            ? .cancelled
            : .failed(error.errorDescription ?? "The cut-out couldn't be made.")
        }
        try await self?.store(media.id, in: package) { analysis in
          analysis.matte = file
          analysis.subjectPath = path
        }
        await self?.useMatte(url, for: media.id)
      }
      return title
    }
  }

  /// Reframes clips (default: the selected ones) to fill the frame around their subject, from
  /// the cut-out's subject path when there is one. Returns how many were reframed.
  public func autoReframe(_ clipIDs: [Clip.ID]?) throws(CommandError) -> Int {
    let timeline = editor.project.timeline
    let ids = clipIDs ?? Array(editor.selection)
    let clips = ids.compactMap(timeline.clip(withID:)).filter { $0.mediaID != nil }
    guard !clips.isEmpty else {
      throw .invalidArguments("pick video clips to reframe")
    }
    let commands = clips.map { clip in
      let center = subjectCenter(of: clip)
      return ReframeClip(clipID: clip.id, centerX: center?.x, centerY: center?.y)
    }
    try editor.perform(commands, title: ReframeClip.title)
    return commands.count
  }

  /// Queues following what's inside `box` of a video clip from `time` to the clip's end, saved
  /// as a path called `name` on its media. Returns the job's title.
  public func trackMotion(
    clipID: Clip.ID,
    at time: MediaTime,
    box: CGRect,
    name: String,
  ) throws(CommandError) -> String {
    guard
      let package = documentURL,
      let clip = editor.project.timeline.clip(withID: clipID),
      let media = clip.mediaID.flatMap(editor.project.media(withID:)), media.hasVideo,
      !media.isStill
    else {
      throw .invalidArguments("pick a video clip on the timeline to track")
    }
    guard clip.contains(time) else {
      throw .invalidRange("the moment must fall inside the clip")
    }
    guard box.width > 0, box.height > 0, CGRect(x: 0, y: 0, width: 1, height: 1).contains(box)
    else {
      throw .invalidValue("the box must sit inside the picture, as fractions from 0 to 1")
    }
    let start = clip.sourceTime(at: time).seconds
    let end = (clip.sourceStart + clip.duration).seconds
    let title = "Tracking \(name) in \(media.name)"
    jobs.enqueue(title) { [weak self] progress throws(JobError) in
      let path: [SubjectPoint]
      do throws(MattingError) {
        path = try await MotionTracker.track(in: media.url, box: box, from: start, to: end) {
          progress($0)
        }
      } catch {
        throw error == .cancelled
          ? .cancelled
          : .failed(error.errorDescription ?? "The box couldn't be followed.")
      }
      try await self?.store(media.id, in: package) { analysis in
        analysis.tracks = (analysis.tracks ?? [:]).merging([name: path]) { $1 }
      }
    }
    return title
  }

  /// Makes a layer follow a path through a video clip: the tracked path called `name`, or the
  /// cut-out's subject.
  public func follow(clipID: Clip.ID, targetID: Clip.ID, path name: String?) throws(CommandError) {
    let analysis = editor.project.timeline.clip(withID: targetID)?.mediaID
      .flatMap { self.analysis.analyses[$0] }
    let path = name.map { analysis?.tracks?[$0] } ?? analysis?.subjectPath
    guard let path else {
      throw .invalidArguments(name.map {
        "there's no path called \($0) on that clip's media; run track_motion first"
      } ?? "that clip has no cut-out yet; run make_cutout first")
    }
    try editor.perform(FollowPath(clipID: clipID, targetID: targetID, path: path))
  }

  /// Places a plugin's template (`plugin/name` or `name`) at `time` with its text fields filled,
  /// importing the stickers and sounds it uses. One undo step. Returns what was added.
  public func applyTemplate(
    named name: String,
    at time: MediaTime,
    fields: [String: String],
  ) async throws(ToolError) -> String {
    guard let (template, plugin) = plugins.template(named: name) else {
      throw .commandFailed(.invalidArguments(
        "there's no template called \(name); list_plugins shows the templates"
      ))
    }
    var commands = [any Command]()
    var media = [String: Media.ID]()
    for layer in template.layers {
      for asset in [layer.sticker, layer.sound].compactMap(\.self) where media[asset] == nil {
        guard let url = plugin.stickers[asset] ?? plugin.sounds[asset] else {
          continue
        }
        if let existing = editor.project.media.first(where: { $0.url == url }) {
          media[asset] = existing.id
          continue
        }
        do {
          let loaded = try await MediaLoader.load(url)
          commands.append(AddMedia(media: loaded))
          media[asset] = loaded.id
        } catch {
          throw .mediaFailed(error)
        }
      }
    }
    commands.append(ApplyTemplate(
      template,
      at: time,
      fields: fields,
      styles: plugin.styles,
      media: media,
    ))
    do {
      try editor.perform(commands, title: "Template \(name)")
    } catch {
      throw .commandFailed(error)
    }
    return "Placed \(name) at \(time.seconds) s: \(template.layers.count) layers."
  }

  /// Ducks a music track (`track`, or the one that sounds like music) under everyone's speech,
  /// to `level` of its own volume. Returns what was done.
  public func duckMusic(track label: String?, level: Double) throws(CommandError) -> String {
    let timeline = editor.project.timeline
    let audio = timeline.tracks.indices.filter { timeline.tracks[$0].kind == .audio }
    let analyses = analysis.analyses
    let has = { (index: Int, test: (MediaAnalysis) -> Bool) in
      timeline.tracks[index].clips.contains { clip in
        clip.mediaID.flatMap { analyses[$0] }.map(test) ?? false
      }
    }
    let length = { (index: Int) in
      timeline.tracks[index].clips.reduce(0) { $0 + $1.duration.seconds }
    }
    // why: music is the track with beats, or failing that the longest track with no speech;
    // short sound effects and dialogue are left alone.
    let candidates = audio
      .filter { !timeline.tracks[$0].clips.isEmpty && !has($0) { $0.speech?.isEmpty == false } }
    let music = label.flatMap { label in
      timeline.tracks.firstIndex { timeline.label(of: $0) == label.uppercased() }
    } ?? candidates.first { has($0) { $0.beats?.beats.isEmpty == false } }
      ?? candidates.max { length($0) < length($1) }
    guard let music, timeline.tracks[music].kind == .audio else {
      throw .invalidArguments("put the music on an audio track (A1, A2…) first")
    }
    let speech = DuckingPlanner.speech(in: timeline, except: music, analyses: analysis.analyses)
    guard !speech.isEmpty else {
      throw .invalidArguments(
        "no speech found yet: run analyze_audio (or transcribe) on the dialogue first"
      )
    }
    try editor.perform(DuckMusic(track: music, speech: speech, duckTo: level))
    let name = timeline.label(of: timeline.tracks[music])
    let percent = Int((level * 100).rounded())
    return "Ducked \(name) to \(percent)% under \(speech.count) stretches of speech."
  }

  /// Measures the mix's loudness and sets the master level so it plays at `target` LUFS,
  /// keeping peaks below -1 dBFS. Returns what was measured and done.
  public func normalizeLoudness(target: Double) async throws(ToolError) -> String {
    let reader = MixReader(project: editor.project, cleanSound: player.cleanSound)
    let loudness: Loudness
    do {
      loudness = try await LoudnessMeter
        .measure { () throws(EngineError) in try await reader.nextChunk() }
    } catch {
      throw .engineFailed(error)
    }
    guard loudness.integrated.isFinite else {
      throw .commandFailed(.invalidArguments("the timeline has no sound to measure"))
    }
    let current = editor.project.timeline.gain
    let wanted = target - loudness.integrated
    // why: -1 dBFS of headroom keeps platforms' encoders from clipping the loudest moments.
    let allowed = -1 - loudness.peak
    let change = min(wanted, allowed)
    let gain = min(max(current * pow(10, change / 20), 0), 8)
    do {
      try editor.perform(SetMasterGain(gain: gain))
    } catch {
      throw .commandFailed(error)
    }
    let result = loudness.integrated + 20 * log10(gain / max(current, 0.0001))
    let limited = change < wanted ? " (held back to keep peaks under -1 dBFS)" : ""
    return String(
      format: "Measured %.1f LUFS (peak %.1f dBFS); master level now %.2f, about %.1f LUFS%@.",
      loudness.integrated,
      loudness.peak,
      gain,
      result,
      limited,
    )
  }

  /// Sets clips to play noise-reduced sound, queuing the cleaning of media that hasn't been
  /// cleaned at `strength` yet. Returns what was done.
  public func reduceNoise(_ clipIDs: [Clip.ID], strength: Double) throws(CommandError) -> String {
    guard let package = documentURL else {
      throw .invalidArguments("open a project first")
    }
    let clips = clipIDs.compactMap(editor.project.timeline.clip(withID:))
    let media = Set(clips.compactMap(\.mediaID)).compactMap(editor.project.media(withID:))
      .filter(\.hasAudio)
    guard !media.isEmpty else {
      throw .invalidArguments("pick clips with sound")
    }
    try editor.perform(
      clips.map { SetClip(clipID: $0.id, cleanSound: strength > 0) },
      title: "Clean Sound",
    )
    guard strength > 0 else {
      return "Those clips play their original sound again."
    }
    let percent = Int((strength * 100).rounded())
    let queued = media
      .filter { analysis.analyses[$0.id]?.cleanSound != "\($0.id.uuidString)-\(percent).m4a" }
    for item in queued {
      let file = "\(item.id.uuidString)-\(percent).m4a"
      let destination = package.appending(path: "cache/sound/\(file)")
      jobs.enqueue("Cleaning the sound of \(item.name)") { [weak self] progress throws(JobError) in
        do {
          let samples = try await AudioDecoder.mono(from: item.url, sampleRate: 48000)
          progress(0.3)
          let cleaned = await NoiseReducer.reduce(samples, sampleRate: 48000, strength: strength)
          progress(0.9)
          try await AudioWriter.writeM4A([cleaned], sampleRate: 48000, to: destination)
        } catch let error as AudioError {
          throw .failed(error.errorDescription ?? "The sound couldn't be cleaned.")
        } catch {
          throw .failed(error.localizedDescription)
        }
        try await self?.store(item.id, in: package) { $0.cleanSound = file }
        await self?.useCleanSound(destination, for: item.id)
      }
    }
    return queued.isEmpty
      ? "Those clips now play their cleaned sound."
      : "Cleaning \(queued.count) file\(queued.count == 1 ? "" : "s") in the background; the "
        + "clips switch over when done."
  }

  /// Queues `request`'s files for export from the timeline as it is now. Each chimes and posts
  /// a notification when it's written. Returns the files' names.
  public func export(_ request: ExportRequest) throws(CommandError) -> [String] {
    let project = editor.project
    guard project.timeline.duration > .zero else {
      throw .invalidArguments("the timeline is empty; add clips first")
    }
    let mattes = player.mattes
    let cleanSound = player.cleanSound
    let transcripts = analysis.transcripts
    let outputs = request.outputs(for: project.timeline)
    for output in outputs {
      let title = "Exporting \(output.url.lastPathComponent)"
      jobs.enqueue(title) { [weak self] progress throws(JobError) in
        do throws(ExportError) {
          try await Exporter.write(
            output,
            of: request,
            project: project,
            mattes: mattes,
            cleanSound: cleanSound,
            transcripts: transcripts,
            progress: progress,
          )
        } catch .cancelled {
          throw .cancelled
        } catch {
          throw .failed(error.errorDescription ?? "The export couldn't be made.")
        }
        await self?.notifier.finished(output.url)
      }
    }
    return outputs.map(\.url.lastPathComponent)
  }

  /// Separates the voice and music of clips' sound in the background (downloading the model the
  /// first time), then lays the two under each clip in its place. Returns what was queued.
  public func separateStems(_ clipIDs: [Clip.ID]) throws(CommandError) -> String {
    guard let package = documentURL else {
      throw .invalidArguments("open a project first")
    }
    let timeline = editor.project.timeline
    // why: a video clip whose sound was detached plays none; its sound clip is the one to split.
    let clips = clipIDs.compactMap(timeline.clip(withID:)).filter { clip in
      clip.isAudioEnabled || timeline.location(ofClip: clip.id)
        .map { timeline.tracks[$0.track].kind == .audio } == true
    }
    let media = Set(clips.compactMap(\.mediaID)).compactMap(editor.project.media(withID:))
      .filter(\.hasAudio)
    guard !media.isEmpty else {
      throw .invalidArguments("pick clips that play sound (a detached video's sound clip, not "
        + "the video)")
    }
    for item in media {
      let saved = analysis.analyses[item.id]?.stems
      let heard = analysis.analyses[item.id]
      let wanted = clips.filter { $0.mediaID == item.id }.map(\.id)
      let title = "Separating the voice and music of \(item.name)"
      jobs.enqueue(title) { [weak self] progress throws(JobError) in
        let files: [Stem: URL]
        do throws(AudioError) {
          files = try await Self.stems(of: item, saved: saved, in: package, progress: progress)
        } catch {
          throw .failed(error.errorDescription ?? "The sound couldn't be separated.")
        }
        try await self?.store(item.id, in: package) { analysis in
          analysis.stems = Dictionary(uniqueKeysWithValues: files.map {
            ($0.key.rawValue, "\(item.id.uuidString)/\($0.value.lastPathComponent)")
          })
        }
        let stems = try await self?.useStems(files, for: wanted) ?? []
        // why: the voice keeps the original's timing, so what was heard in it still applies.
        if let voice = stems.first, heard?.transcript != nil || heard?.speech != nil {
          try await self?.store(voice.id, in: package) { analysis in
            analysis.transcript = heard?.transcript
            analysis.speech = heard?.speech
          }
        }
      }
    }
    return "Separating \(media.count) file\(media.count == 1 ? "" : "s") in the background; the "
      + "voice and music land under each clip when done."
  }

  // MARK: Internal

  /// Makes a layer follow the subject of the topmost video under it that has a cut-out.
  func followSubject(_ clipID: Clip.ID) throws(CommandError) {
    let timeline = editor.project.timeline
    guard let clip = timeline.clip(withID: clipID) else {
      throw .clipNotFound(clipID)
    }
    let target = timeline.tracks.reversed().filter { $0.kind == .video }.lazy
      .compactMap { track in
        track.clips.first { candidate in
          candidate.id != clipID && candidate.timelineStart < clip.timelineEnd
            && clip.timelineStart < candidate.timelineEnd
            && candidate.mediaID.flatMap { self.analysis.analyses[$0]?.subjectPath } != nil
        }
      }.first
    guard let target else {
      throw .invalidArguments(
        "there's no cut-out video under this layer; cut out its subject first"
      )
    }
    try follow(clipID: clipID, targetID: target.id, path: nil)
  }

  // MARK: Private

  /// The separated sound of `media`: the files saved before, or freshly separated ones.
  @concurrent
  private static func stems(
    of media: Media,
    saved: [String: String]?,
    in package: URL,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(AudioError) -> [Stem: URL] {
    // why: the file name becomes the stem clip's name; the folder keeps it unique.
    let folder = package.appending(path: "cache/stems/\(media.id.uuidString)")
    let files = Dictionary(uniqueKeysWithValues: Stem.allCases.map { stem in
      (stem, folder.appending(path: "\(media.name) \(stem.rawValue).m4a"))
    })
    if saved != nil, files.values.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) {
      return files
    }
    if !StemModel.isReady {
      try await StemModel.download()
    }
    let stems = try await StemSeparator.separate(
      media.url,
      modelURL: StemModel.url,
      progress: { progress($0 * 0.9) },
    )
    for (stem, url) in files {
      try await AudioWriter.writeM4A(
        stems[stem] ?? [],
        sampleRate: StemSeparator.sampleRate,
        to: url,
      )
    }
    return files
  }

  /// Starts using a finished noise-reduced sound in playback.
  private func useCleanSound(_ url: URL, for mediaID: Media.ID) async {
    player.cleanSound[mediaID] = url
    try? await player.load(editor.project) // why: the editor shows playback errors.
  }

  /// Lays separated voice and music under each of `clipIDs` still on the timeline, as one step,
  /// and returns the stems' media (voice first).
  @discardableResult
  private func useStems(
    _ files: [Stem: URL],
    for clipIDs: [Clip.ID],
  ) async throws(JobError) -> [Media] {
    var stems = [Media]()
    for stem in Stem.allCases {
      guard let url = files[stem] else {
        continue
      }
      if let existing = editor.project.media.first(where: { $0.url == url }) {
        stems.append(existing)
        continue
      }
      do {
        stems.append(try await MediaLoader.load(url))
      } catch {
        throw .failed(error.errorDescription ?? "The separated sound couldn't be read.")
      }
    }
    let commands = clipIDs.filter { editor.project.timeline.clip(withID: $0) != nil }
      .map { UseStems(clipID: $0, stems: stems) }
    do {
      try editor.perform(commands, title: UseStems.title)
    } catch {
      throw .failed(error.errorDescription ?? "The separated sound couldn't be placed.")
    }
    return stems
  }

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

  /// The subject's typical position while `clip` plays: the median of its path in that stretch.
  private func subjectCenter(of clip: Clip) -> (x: Double, y: Double)? {
    guard let mediaID = clip.mediaID, let path = analysis.analyses[mediaID]?.subjectPath else {
      return nil
    }
    let end = clip.sourceStart + clip.duration
    let inside = path.filter { clip.sourceStart <= $0.time && $0.time < end }
    guard !inside.isEmpty else {
      return nil
    }
    let xs = inside.map(\.x).sorted()
    let ys = inside.map(\.y).sorted()
    return (xs[xs.count / 2], ys[ys.count / 2])
  }

  /// Starts using a finished cut-out in playback.
  private func useMatte(_ url: URL, for mediaID: Media.ID) async {
    player.mattes[mediaID] = url
    try? await player.load(editor.project) // why: the editor shows playback errors.
  }

}
