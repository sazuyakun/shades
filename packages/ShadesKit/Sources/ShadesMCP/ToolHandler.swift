import Foundation
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesMedia

// MARK: - ToolHandler

/// Shades as Claude tools: the built-in ones (read, see, import, transport, undo, batch) plus
/// every command in `CommandRegistry`. Each call that changes the project is one undo step and
/// one History entry.
@MainActor
public final class ToolHandler {

  // MARK: Lifecycle

  public init(editor: Editor, player: Player, activity: ActivityLog, jobs: JobQueue = JobQueue()) {
    self.editor = editor
    self.player = player
    self.activity = activity
    self.jobs = jobs
  }

  // MARK: Public

  /// Runs before every call that may change the project, e.g. to snapshot it first.
  public var beforeEdit: () -> Void = { }
  /// Who holds the open project, for the project tools.
  public weak var projectHost: (any ProjectHost)?

  /// Runs a tool. Failures come back as an error result Claude can read and act on.
  public func call(_ name: String, arguments: JSONValue) async -> ToolResult {
    let isEdit = (Self.builtIns.first { $0.name == name }?.kind ?? .edit) == .edit
    if isEdit {
      beforeEdit()
    }
    let before = editor.project
    let result: ToolResult
    do {
      result = try await run(name, arguments: arguments)
    } catch {
      result = .failure(error.errorDescription ?? "The tool failed.")
    }
    if isEdit, editor.project != before || result.isError {
      let previous = Set(before.timeline.allClips)
      activity.record(ActivityEntry(
        title: title(of: name, arguments: arguments),
        summary: result.text,
        isError: result.isError,
        changedClipIDs: Set(editor.project.timeline.allClips.filter { !previous.contains($0) }
          .map(\.id)),
      ))
    }
    return result
  }

  // MARK: Internal

  /// Every tool, built-ins first.
  var tools: [Tool] {
    Self.builtIns + CommandRegistry.tools.map { command in
      Tool(
        name: command.name,
        summary: command.summary,
        parameters: command.parameters,
        kind: .edit,
      )
    }
  }

  // MARK: Private

  private static let builtIns = [
    Tool(
      name: "get_project",
      summary: "Get the whole project: media, tracks with their clips, markers, the playhead "
        + "and the selection. Times are in seconds.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "get_guide",
      summary: "Read how Shades works and how to edit well with these tools.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "import_media",
      summary: "Import a video or audio file from disk (it stays where it is). Returns its ID.",
      parameters: JSONSchema.object(
        ["path": JSONSchema.string("Absolute path to the file")],
        required: ["path"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "render_frame",
      summary: "Render the timeline at a time as an image, to check how it looks.",
      parameters: JSONSchema.object(
        [
          "seconds": JSONSchema.number("Time on the timeline", minimum: 0),
          "max_side": JSONSchema.number(
            "Longest side in pixels (default 768)",
            minimum: 64,
            maximum: 2880,
          ),
        ],
        required: ["seconds"],
      ),
      kind: .read,
    ),
    Tool(
      name: "get_jobs",
      summary: "List background jobs (proxies, transcripts, analysis): running, waiting and just "
        + "finished, with progress.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "select_clips",
      summary: "Select clips on the timeline, to point the user at them (an empty list clears).",
      parameters: JSONSchema.object(
        ["clip_ids": JSONSchema.array(
          "IDs of clips to select",
          items: JSONSchema.string("A clip ID"),
        )],
        required: ["clip_ids"],
      ),
      kind: .read,
    ),
    Tool(
      name: "play",
      summary: "Start playback in the viewer.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "pause",
      summary: "Pause playback.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "seek",
      summary: "Move the playhead to a time on the timeline.",
      parameters: JSONSchema.object(
        ["seconds": JSONSchema.number("Time on the timeline", minimum: 0)],
        required: ["seconds"],
      ),
      kind: .read,
    ),
    Tool(
      name: "undo",
      summary: "Undo the last edit.",
      parameters: JSONSchema.object([:]),
      kind: .edit,
    ),
    Tool(
      name: "redo",
      summary: "Redo the last undone edit.",
      parameters: JSONSchema.object([:]),
      kind: .edit,
    ),
    Tool(
      name: "batch",
      summary: "Apply many edit tools in order as one undo step, all or nothing. Each edit names "
        + "a tool (like split_clip) and its arguments.",
      parameters: JSONSchema.object(
        [
          "edits": JSONSchema.array(
            "The edits, applied in order",
            items: JSONSchema.object(
              [
                "tool": JSONSchema.string("An edit tool's name"),
                "arguments": JSONSchema.object([:]),
              ],
              required: ["tool"],
            ),
          )
        ],
        required: ["edits"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "list_projects",
      summary: "List the projects in ~/Shades, newest first, and which one is open.",
      parameters: JSONSchema.object([:]),
      kind: .project,
    ),
    Tool(
      name: "new_project",
      summary: "Create a project in ~/Shades and open it. The picture is always 4:3.",
      parameters: JSONSchema.object(
        [
          "name": JSONSchema.string("The project's name"),
          "size": JSONSchema.string(
            "Picture size (default 2880x2160)",
            values: ["2880x2160", "1440x1080"],
          ),
          "fps": JSONSchema.number("Frame rate: 24 (default), 30 or 60"),
        ],
        required: ["name"],
      ),
      kind: .project,
    ),
    Tool(
      name: "open_project",
      summary: "Save the open project and open another, by name (from list_projects) or path.",
      parameters: JSONSchema.object(
        ["name": JSONSchema.string("A project name, or the path to a .shades package")],
        required: ["name"],
      ),
      kind: .project,
    ),
  ]

  private let editor: Editor
  private let player: Player
  private let activity: ActivityLog
  private let jobs: JobQueue

  private func run(_ name: String, arguments: JSONValue) async throws(ToolError) -> ToolResult {
    switch name {
    case "get_project":
      return try json(ProjectSummary.json(
        of: editor.project,
        playhead: player.currentTime,
        selection: editor.selection,
      ))

    case "get_guide":
      return .text(Guide.text)

    case "import_media":
      return try await importMedia(decode(PathArguments.self, from: arguments, tool: name).path)

    case "render_frame":
      let frame = try decode(FrameArguments.self, from: arguments, tool: name)
      return try await renderFrame(atSeconds: frame.seconds, maxSide: frame.maxSide ?? 768)

    case "get_jobs":
      return .text(jobsReport())

    case "select_clips":
      let ids = try decode(SelectArguments.self, from: arguments, tool: name).clipIDs
      editor.selection = Set(ids.filter { editor.project.timeline.clip(withID: $0) != nil })
      return .text(
        "Selected \(editor.selection.count) clip\(editor.selection.count == 1 ? "" : "s")."
      )

    case "play":
      player.play()
      return .text("Playing.")

    case "pause":
      player.pause()
      return .text("Paused at \(player.currentTime) seconds.")

    case "seek":
      await player
        .seek(toSeconds: try decode(SeekArguments.self, from: arguments, tool: name).seconds)
      return .text("Playhead at \(player.currentTime) seconds.")

    case "undo":
      let title = editor.undoTitle
      try perform { () throws(CommandError) in try editor.undo() }
      return .text("Undid \(title ?? "the last edit").")

    case "redo":
      let title = editor.redoTitle
      try perform { () throws(CommandError) in try editor.redo() }
      return .text("Redid \(title ?? "the last edit").")

    case "batch":
      return try batch(arguments)

    case "list_projects":
      return await listProjects()

    case "new_project":
      return try await newProject(decode(NewProjectArguments.self, from: arguments, tool: name))

    case "open_project":
      return try await openProject(decode(NameArguments.self, from: arguments, tool: name).name)

    default:
      return try edit(name, arguments: arguments)
    }
  }

  /// Runs one registry command as its own undo step.
  private func edit(_ name: String, arguments: JSONValue) throws(ToolError) -> ToolResult {
    let before = editor.project
    try perform { () throws(CommandError) in
      try editor.perform(CommandRegistry.command(named: name, arguments: arguments))
    }
    return .text(report(since: before))
  }

  /// Runs several registry commands as one undo step.
  private func batch(_ arguments: JSONValue) throws(ToolError) -> ToolResult {
    guard case .array(let edits) = arguments["edits"] else {
      throw rejected(.commandFailed(.invalidArguments("missing edits")), tool: "batch")
    }
    let before = editor.project
    try perform { () throws(CommandError) in
      var commands = [any Command]()
      for (index, edit) in edits.enumerated() {
        guard let tool = edit["tool"]?.stringValue else {
          throw CommandError.invalidArguments("edit \(index + 1) has no tool")
        }
        do throws(CommandError) {
          try commands.append(CommandRegistry.command(
            named: tool,
            arguments: edit["arguments"] ?? [:],
          ))
        } catch {
          throw CommandError
            .invalidArguments("edit \(index + 1) (\(tool)): \(error.errorDescription ?? "")")
        }
      }
      try editor.perform(commands, title: "Batch of \(commands.count) Edits")
    }
    return .text(report(since: before))
  }

  private func importMedia(_ path: String) async throws(ToolError) -> ToolResult {
    let media: Media
    do {
      media = try await MediaLoader.load(URL(filePath: path))
    } catch {
      throw .mediaFailed(error)
    }
    try perform { () throws(CommandError) in try editor.perform(AddMedia(media: media)) }
    let picture = media.hasVideo ? "\(media.width)×\(media.height), " : "sound only, "
    return .text(
      "Imported \(media.name) as media \(media.id): \(media.duration.seconds) s, \(picture)"
        + "\(media.hasAudio ? "with" : "no") audio."
    )
  }

  private func renderFrame(
    atSeconds seconds: Double,
    maxSide: Int,
  ) async throws(ToolError) -> ToolResult {
    do {
      let png = try await FrameRenderer.png(
        of: editor.project,
        atSeconds: seconds,
        maxSide: maxSide,
      )
      return ToolResult(content: [.png(png)])
    } catch {
      throw .engineFailed(error)
    }
  }

  private func listProjects() async -> ToolResult {
    let open = projectHost?.documentURL
    let entries = await ProjectLibrary.projects()
    guard !entries.isEmpty else {
      return .text("There are no projects in ~/Shades yet. Create one with new_project.")
    }
    return .text(entries.map { entry in
      "- \(entry.name)\(entry.url == open ? " (open)" : "")"
    }
    .joined(separator: "\n"))
  }

  private func newProject(_ arguments: NewProjectArguments) async throws(ToolError) -> ToolResult {
    guard let host = projectHost else {
      throw noHost()
    }
    let size: VideoFormat = arguments.size == "1440x1080" ? .half : .standard
    let fps = arguments.fps ?? 24
    guard VideoFormat.frameRates.contains(fps) else {
      throw rejected(.commandFailed(.invalidValue("fps must be 24, 30 or 60")), tool: "new_project")
    }
    do {
      try await host.createProject(named: arguments.name, format: size.withFrameRate(fps))
    } catch {
      throw .documentFailed(error)
    }
    return .text("Created and opened \(arguments.name) (\(size.width)×\(size.height), \(fps) fps).")
  }

  private func openProject(_ name: String) async throws(ToolError) -> ToolResult {
    guard let host = projectHost else {
      throw noHost()
    }
    let url = name.hasPrefix("/")
      ? URL(filePath: name, directoryHint: .isDirectory)
      : ProjectLibrary.folder.appending(
        path: "\(name).\(ProjectFile.fileExtension)",
        directoryHint: .isDirectory,
      )
    do {
      try await host.openProject(at: url)
    } catch {
      throw .documentFailed(error)
    }
    return .text("Opened \(url.deletingPathExtension().lastPathComponent).")
  }

  private func jobsReport() -> String {
    guard !jobs.jobs.isEmpty else {
      return "No background jobs."
    }
    var lines = jobs.jobs.map { job in
      let state =
        switch job.state {
        case .queued: "waiting"
        case .running(let progress): progress.map { "running, \(Int($0 * 100))%" } ?? "running"
        case .done: "done"
        case .failed(let message): "failed: \(message)"
        case .cancelled: "cancelled"
        }
      return "- \(job.title): \(state)"
    }
    if let reason = jobs.pauseReason {
      lines.append(reason)
    }
    return lines.joined(separator: "\n")
  }

  private func noHost() -> ToolError {
    logger.fault("tool.failed reason=noProjectHost")
    assertionFailure("The MCP server has no project host")
    return .noProjectHost
  }

  /// What an edit changed, so Claude learns new clip IDs without calling get_project.
  private func report(since before: Project) -> String {
    let timeline = editor.project.timeline
    let previous = Set(before.timeline.allClips)
    let changed = timeline.allClips.filter { !previous.contains($0) }
    let removed = before.timeline.allClips.count { timeline.clip(withID: $0.id) == nil }
    var lines =
      ["Done. The timeline is \(String(format: "%.3f", timeline.duration.seconds)) s long."]
    if !changed.isEmpty {
      lines.append("New or changed clips:")
      lines += changed.map { "- " + ProjectSummary.describe($0, in: timeline) }
    }
    if removed > 0 {
      lines.append("Removed \(removed) clip\(removed == 1 ? "" : "s").")
    }
    return lines.joined(separator: "\n")
  }

  /// The History title for a call, e.g. "Split Clip".
  private func title(of name: String, arguments _: JSONValue) -> String {
    switch name {
    case "import_media": AddMedia.title
    case "undo": "Undo"
    case "redo": "Redo"
    case "batch": "Batch of Edits"
    default: CommandRegistry.tools.first { $0.name == name }?.title ?? name
    }
  }

  /// Runs project work, wrapping its error for MCP. (Commands log their own rejections.)
  private func perform(_ work: () throws(CommandError) -> Void) throws(ToolError) {
    do {
      try work()
    } catch {
      throw .commandFailed(error)
    }
  }

  /// Decodes a built-in tool's arguments, logging a rejection where it happens.
  private func decode<T: Decodable>(
    _: T.Type,
    from arguments: JSONValue,
    tool: String,
  ) throws(ToolError) -> T {
    do {
      return try arguments.decode(T.self)
    } catch {
      throw rejected(.commandFailed(error), tool: tool)
    }
  }

  private func rejected(_ error: ToolError, tool: String) -> ToolError {
    logger.error("tool.rejected reason=invalidArguments tool=\(tool, privacy: .public)")
    return error
  }

  private func json(_ value: JSONValue) throws(ToolError) -> ToolResult {
    do {
      return try .text(String(decoding: value.jsonData(pretty: true), as: UTF8.self))
    } catch {
      throw .commandFailed(error)
    }
  }

}

// MARK: - PathArguments

private struct PathArguments: Decodable {
  let path: String
}

// MARK: - FrameArguments

private struct FrameArguments: Decodable {
  let seconds: Double
  let maxSide: Int?
}

// MARK: - NewProjectArguments

private struct NewProjectArguments: Decodable {
  let name: String
  let size: String?
  let fps: Int?
}

// MARK: - NameArguments

private struct NameArguments: Decodable {
  let name: String
}

// MARK: - SelectArguments

private struct SelectArguments: Decodable {
  let clipIDs: [UUID]
}

// MARK: - SeekArguments

private struct SeekArguments: Decodable {
  let seconds: Double
}
