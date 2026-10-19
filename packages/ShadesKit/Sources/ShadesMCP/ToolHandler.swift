import Foundation
import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesExport
import ShadesMatting
import ShadesMedia
import ShadesPlugins
import ShadesPolish

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

  private static let builtIns: [Tool] = [
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
      name: "get_scopes",
      summary: "See the colour of a frame like a colourist: waveform, vectorscope and RGB "
        + "histogram, plus average brightness, clipped highlights, crushed shadows and "
        + "saturation. Use it to check a grade.",
      parameters: JSONSchema.object(
        ["seconds": Fields.time("Which frame")],
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
      name: "transcribe",
      summary: "Transcribe speech in the background (word timings, on this Mac). By default every "
        +
        "clip with sound on the timeline that has no transcript yet. Watch progress with get_jobs.",
      parameters: JSONSchema.object([
        "media_ids": JSONSchema.array("Media to transcribe", items: Fields.mediaID),
        "model": JSONSchema.string(
          "Speech model: small (default, balanced), base (fastest) or large_turbo (best for "
            + "Hinglish, slower)",
          values: ["base", "small", "large_turbo"],
        ),
        "language": JSONSchema.string("Language code like en or hi; leave out to detect"),
      ]),
      kind: .project,
    ),
    Tool(
      name: "analyze_audio",
      summary: "Find when people talk and the music's beats, in the background. By default every "
        + "clip with sound on the timeline not analysed yet.",
      parameters: JSONSchema.object(["media_ids": JSONSchema.array(
        "Media to analyse",
        items: Fields.mediaID,
      )]),
      kind: .project,
    ),
    Tool(
      name: "get_transcript",
      summary: "What's said on the timeline, as caption-sized lines with timeline times. Pass "
        + "words: true for every word's time (for cutting words with remove_ranges).",
      parameters: JSONSchema.object([
        "start": Fields.time("From"),
        "end": Fields.time("Up to"),
        "words": JSONSchema.boolean("List every word with its time"),
      ]),
      kind: .read,
    ),
    Tool(
      name: "get_analysis",
      summary: "What's been worked out for each media file: transcript language and length, "
        + "speech stretches and beats (in the file's own time).",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "add_captions",
      summary: "Add captions for what's said (in a range, or everywhere) as text clips on a text "
        + "track, with each word's timing for kinetic reveals. Needs transcripts first. Edit them "
        + "afterwards with set_text.",
      parameters: JSONSchema.object([
        "start": Fields.time("From"),
        "end": Fields.time("Up to"),
        "reveal": Fields.reveal,
        "style": Fields.textStyle,
      ]),
      kind: .edit,
    ),
    Tool(
      name: "polish_propose",
      summary: "Propose Polish for talking-head footage on a stretch of a track: cut silences and "
        + "fillers (um, uh, matlab…), remove retakes, snap cuts to music beats, punch in on jump "
        + "cuts. Nothing changes yet: the plan shows on the timeline for review. Transcribe "
        + "first for the best results (analyze_audio for beats).",
      parameters: JSONSchema.object(
        [
          "start": Fields.time("From"),
          "end": Fields.time("Up to"),
          "track": Fields.track,
          "silences": JSONSchema.boolean("Cut pauses (default true)"),
          "fillers": JSONSchema.boolean("Cut filler words (default true)"),
          "retakes": JSONSchema.boolean("Remove restarted lines (default true)"),
          "beat_snap": JSONSchema.boolean("Move cuts onto music beats (default true)"),
          "punch_in": JSONSchema.boolean("Zoom every second stretch between cuts (default true)"),
          "min_silence": JSONSchema.number(
            "Shortest pause to cut, in seconds (default 0.6)",
            minimum: 0.1,
          ),
        ],
        required: ["start", "end"],
      ),
      kind: .project,
    ),
    Tool(
      name: "polish_apply",
      summary: "Apply the Polish plan as one undo step: every switched-on item, or only the given "
        + "item IDs or kinds (silence, filler, retake, beatSnap, punchIn).",
      parameters: JSONSchema.object([
        "item_ids": JSONSchema.array("Plan items to apply", items: JSONSchema.string("An item ID")),
        "kinds": JSONSchema.array(
          "Kinds of item to apply",
          items: JSONSchema.string("A kind", values: PolishKind.allCases.map(\.rawValue)),
        ),
      ]),
      kind: .edit,
    ),
    Tool(
      name: "polish_discard",
      summary: "Throw away the Polish plan without changing anything.",
      parameters: JSONSchema.object([:]),
      kind: .project,
    ),
    Tool(
      name: "make_cutout",
      summary: "Cut out the subject (person or object) of video clips in the background, for text "
        + "behind people and other depth slots (set_clip depth_slot) and for auto_reframe. By "
        + "default every video on the timeline without a cut-out.",
      parameters: JSONSchema.object([
        "media_ids": JSONSchema.array("Media to cut out", items: Fields.mediaID),
        "engine": JSONSchema.string(
          "visionPerson (people, default) or visionForeground (any subject)",
          values: MatteEngine.allCases.map(\.rawValue),
        ),
      ]),
      kind: .project,
    ),
    Tool(
      name: "auto_reframe",
      summary: "Zoom clips to fill the 4:3 frame (no black bars), keeping their subject in view "
        + "using the cut-out's subject path. Default: the selected clips.",
      parameters: JSONSchema.object(["clip_ids": Fields.clipIDs]),
      kind: .edit,
    ),
    Tool(
      name: "cutout_from_frame",
      summary: "Cut the subject (a person or object) out of one frame of a video clip and import "
        + "it as a picture with a see-through background, ready for add_sticker.",
      parameters: JSONSchema.object(
        [
          "clip_id": Fields.clipID,
          "at": Fields.time("The moment to cut out, inside the clip"),
          "engine": JSONSchema.string(
            "visionPerson (people, default) or visionForeground (any subject)",
            values: MatteEngine.allCases.map(\.rawValue),
          ),
        ],
        required: ["clip_id", "at"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "track_motion",
      summary: "Follow something through a video clip in the background, from a box drawn around "
        + "it at one moment to the clip's end (or until it's lost), saved as a named path for "
        + "follow. Check the box with render_frame first.",
      parameters: JSONSchema.object(
        [
          "clip_id": Fields.clipID,
          "at": Fields.time("A moment inside the clip where the thing is clearly visible"),
          "box": JSONSchema.object(
            [
              "x": JSONSchema.number("Left edge, 0 left to 1 right of the clip's picture"),
              "y": JSONSchema.number("Top edge, 0 top to 1 bottom"),
              "width": JSONSchema.number("Width, as a fraction of the picture"),
              "height": JSONSchema.number("Height, as a fraction of the picture"),
            ],
            required: ["x", "y", "width", "height"],
          ),
          "name": JSONSchema.string("A name for the path, like ball or face"),
        ],
        required: ["clip_id", "at", "box", "name"],
      ),
      kind: .project,
    ),
    Tool(
      name: "follow",
      summary: "Make a layer (text, sticker, video) follow something moving in a video clip, "
        + "keeping where it sits now relative to it: x and y keyframes along a track_motion path, "
        + "or along the subject of the clip's cut-out when no path is named.",
      parameters: JSONSchema.object(
        [
          "clip_id": JSONSchema.string("The layer that moves"),
          "target_id": JSONSchema.string("The video clip with the moving thing"),
          "path": JSONSchema.string("A track_motion path's name; leave out to follow the subject"),
        ],
        required: ["clip_id", "target_id"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "list_plugins",
      summary: "List the plugins (taste packs): their text styles, templates (with the fields they "
        + "ask for), stickers and sounds (with file paths to import), and any manifest problems. "
        + "Plugins are folders with a plugin.json; write or edit one and it reloads by itself.",
      parameters: JSONSchema.object([:]),
      kind: .read,
    ),
    Tool(
      name: "apply_template",
      summary: "Place a plugin's title or motion template at a moment, filling its {fields}. Its "
        + "stickers and sounds are imported for you. One undo step.",
      parameters: JSONSchema.object(
        [
          "name": JSONSchema.string("The template, as plugin/name or just name"),
          "at": Fields.time("When it starts"),
          "fields": JSONSchema.object([:]),
        ],
        required: ["name", "at"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "add_sound",
      summary: "Place a sound effect at a moment on a free audio track: a plugin's sound by "
        + "name (list_plugins shows them) or any sound file by path. It's imported for you. Use "
        + "it for whooshes, pops and risers that land on cuts and captions.",
      parameters: JSONSchema.object(
        [
          "sound": JSONSchema.string("The sound, as plugin/name, name or a file path"),
          "at": Fields.time("When it starts"),
          "volume": JSONSchema.number("Its level: 0 silent, 1 unchanged (default)", minimum: 0),
        ],
        required: ["sound", "at"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "use_look",
      summary: "Give clips (or an adjustment clip) a plugin's look: its grade, effects and blend.",
      parameters: JSONSchema.object(
        ["clip_ids": Fields.clipIDs, "look": JSONSchema.string("The look's name")],
        required: ["clip_ids", "look"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "use_style",
      summary: "Give text clips a plugin's text style (by plugin/name or name).",
      parameters: JSONSchema.object(
        ["clip_ids": Fields.clipIDs, "style": JSONSchema.string("The style's name")],
        required: ["clip_ids", "style"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "normalize_loudness",
      summary: "Measure the whole mix's loudness (LUFS, like YouTube and Instagram do) and set the "
        + "master level to hit a target, keeping peaks under -1 dBFS. Do it last, after the mix.",
      parameters: JSONSchema.object([
        "target": JSONSchema.number(
          "Loudness in LUFS (default -14, YouTube; -16 for quieter platforms)",
          minimum: -40,
          maximum: -5,
        )
      ]),
      kind: .edit,
    ),
    Tool(
      name: "export",
      summary: "Export in the background (get_jobs shows progress; Shades chimes when done): "
        + "youtube (the picture on 16:9 black), shorts (each marked short on 9:16, or the "
        + "whole timeline), frame (a PNG at `at`), gif (start to end, up to 30 s) or srt "
        + "(captions). Files go to `folder` (default ~/Movies), named after `name`.",
      parameters: JSONSchema.object(
        [
          "kind": JSONSchema.string(
            "What to export",
            values: ExportKind.allCases.map(\.rawValue),
          ),
          "name": JSONSchema.string("File name without extension (default: the project's)"),
          "folder": JSONSchema.string("Folder path (default ~/Movies)"),
          "codec": JSONSchema.string(
            "Video codec (default hevc)",
            values: VideoCodec.allCases.map(\.rawValue),
          ),
          "at": Fields.time("The frame's moment (frame)"),
          "start": Fields.time("Where the GIF or video starts (default: the beginning)"),
          "end": Fields.time("Where the GIF or video ends (default: the end)"),
        ],
        required: ["kind"],
      ),
      kind: .project,
    ),
    Tool(
      name: "separate_stems",
      summary: "Split clips' sound into voice and music (HTDemucs, on this Mac): both land on "
        + "audio tracks under each clip, lined up, and the clip's own sound goes quiet. Runs in "
        + "the background (get_jobs); the first time it downloads the model (about 100 MB). Use "
        + "it to drop or duck a song under speech, or keep the music without the talking.",
      parameters: JSONSchema.object(["clip_ids": Fields.clipIDs], required: ["clip_ids"]),
      kind: .edit,
    ),
    Tool(
      name: "reduce_noise",
      summary: "Take steady background noise (hiss, hum, fans, traffic rumble) out of clips' "
        + "sound, keeping the voice. Cleaning runs in the background (get_jobs); the clips "
        + "switch over when it's done. Strength 0 goes back to the original.",
      parameters: JSONSchema.object(
        [
          "clip_ids": Fields.clipIDs,
          "strength": JSONSchema.number(
            "0 to 1 (default 0.7); higher removes more",
            minimum: 0,
            maximum: 1,
          ),
        ],
        required: ["clip_ids"],
      ),
      kind: .edit,
    ),
    Tool(
      name: "duck_music",
      summary: "Lower the music while anyone speaks, coming back up between: volume keyframes on "
        + "the music track's clips (the audio track with beats, or the longest without speech, "
        + "unless named). Needs speech analysis "
        + "(analyze_audio or transcribe) on the dialogue first.",
      parameters: JSONSchema.object([
        "track": JSONSchema.string("The music track, like A2"),
        "level": JSONSchema.number(
          "The music's level under speech, 0 to 1 (default 0.25, about 12 dB down)",
          minimum: 0,
          maximum: 1,
        ),
      ]),
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

    case "get_scopes":
      let frame = try decode(FrameArguments.self, from: arguments, tool: name)
      return try await scopes(atSeconds: frame.seconds)

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

    case "transcribe":
      let request = try decode(TranscribeArguments.self, from: arguments, tool: name)
      return queued(try host().transcribe(
        request.mediaIDs,
        model: request.model.flatMap(TranscriptionModel.init(argument:)) ?? .small,
        language: request.language,
      ), nothingLeft: "Every clip with sound already has a transcript.")

    case "analyze_audio":
      let request = try decode(MediaListArguments.self, from: arguments, tool: name)
      return queued(
        try host().analyzeAudio(request.mediaIDs),
        nothingLeft: "Every clip with sound is already analysed.",
      )

    case "get_transcript":
      return try transcript(decode(RangeArguments.self, from: arguments, tool: name))

    case "get_analysis":
      return try analysisReport()

    case "add_captions":
      let request = try decode(CaptionArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      let count = try perform { () throws(CommandError) -> Int in
        try projectHost.addCaptions(
          in: request.range,
          reveal: request.reveal ?? .none,
          style: request.style,
        )
      }
      return .text("Added \(count) captions on a text track.")

    case "polish_propose":
      let request = try decode(PolishArguments.self, from: arguments, tool: name)
      let plan = try host().proposePolish(
        in: request.range,
        track: request.track,
        options: request.options,
      )
      return .text(describe(plan))

    case "polish_apply":
      let request = try decode(PolishApplyArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      let kinds = request.kinds.map { Set($0.compactMap(PolishKind.init(rawValue:))) }
      return .text(try perform { () throws(CommandError) -> String in
        try projectHost.applyPolish(ids: request.itemIDs.map(Set.init), kinds: kinds)
      })

    case "polish_discard":
      try host().discardPolish()
      return .text("The Polish plan was thrown away.")

    case "make_cutout":
      let request = try decode(CutoutArguments.self, from: arguments, tool: name)
      let engine = request.engine.flatMap(MatteEngine.init(rawValue:)) ?? .visionPerson
      return queued(
        try host().makeCutouts(request.mediaIDs, engine: engine),
        nothingLeft: "Every video on the timeline already has a cut-out.",
      )

    case "auto_reframe":
      let request = try decode(ClipListArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      let count = try perform { () throws(CommandError) -> Int in
        try projectHost.autoReframe(request.clipIDs)
      }
      return .text(
        "Reframed \(count) clip\(count == 1 ? "" : "s") to fill the frame around the subject."
      )

    case "cutout_from_frame":
      let request = try decode(CutoutFrameArguments.self, from: arguments, tool: name)
      return try await cutoutFromFrame(request)

    case "track_motion":
      let request = try decode(TrackArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      return queued([try perform { () throws(CommandError) -> String in
        try projectHost.trackMotion(
          clipID: request.clipID,
          at: request.at,
          box: CGRect(
            x: request.box.x,
            y: request.box.y,
            width: request.box.width,
            height: request.box.height,
          ),
          name: request.name,
        )
      }], nothingLeft: "")

    case "follow":
      let request = try decode(FollowArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      try perform { () throws(CommandError) in
        try projectHost.follow(
          clipID: request.clipID,
          targetID: request.targetID,
          path: request.path,
        )
      }
      return .text(
        "The layer now follows \(request.path ?? "the subject"). Check it with render_frame."
      )

    case "list_plugins":
      return try .text(pluginsReport())

    case "apply_template":
      let request = try decode(TemplateArguments.self, from: arguments, tool: name)
      return try await .text(host().applyTemplate(
        named: request.name,
        at: request.at,
        fields: request.fields ?? [:],
      ))

    case "add_sound":
      return try await addSound(decode(SoundArguments.self, from: arguments, tool: name))

    case "use_look":
      let request = try decode(LookArguments.self, from: arguments, tool: name)
      guard let look = try host().plugins.look(named: request.look) else {
        throw .commandFailed(.invalidArguments(
          "there's no look called \(request.look); list_plugins shows the looks"
        ))
      }
      try perform { () throws(CommandError) in
        try editor.perform(SetLook(
          clipIDs: request.clipIDs,
          grade: look.grade,
          effects: look.effects,
          blend: look.blend,
          clear: true,
        ))
      }
      return .text("Gave \(request.clipIDs.count) clips the \(request.look) look.")

    case "use_style":
      let request = try decode(StyleArguments.self, from: arguments, tool: name)
      guard let style = try host().plugins.style(named: request.style) else {
        throw .commandFailed(.invalidArguments(
          "there's no style called \(request.style); list_plugins shows the styles"
        ))
      }
      try perform { () throws(CommandError) in
        try editor.perform(
          request.clipIDs.map { SetText(clipID: $0, style: style) },
          title: "Style \(request.style)",
        )
      }
      return .text("Styled \(request.clipIDs.count) text clips with \(request.style).")

    case "normalize_loudness":
      let request = try decode(LoudnessArguments.self, from: arguments, tool: name)
      return try await .text(host().normalizeLoudness(target: request.target ?? -14))

    case "export":
      return try exportFiles(decode(ExportArguments.self, from: arguments, tool: name))

    case "separate_stems":
      let clipIDs = try decode(SelectArguments.self, from: arguments, tool: name).clipIDs
      let projectHost = try host()
      return .text(try perform { () throws(CommandError) -> String in
        try projectHost.separateStems(clipIDs)
      })

    case "reduce_noise":
      let request = try decode(NoiseArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      return .text(try perform { () throws(CommandError) -> String in
        try projectHost.reduceNoise(request.clipIDs, strength: request.strength ?? 0.7)
      })

    case "duck_music":
      let request = try decode(DuckArguments.self, from: arguments, tool: name)
      let projectHost = try host()
      return .text(try perform { () throws(CommandError) -> String in
        try projectHost.duckMusic(track: request.track, level: request.level ?? 0.25)
      })

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
    let arguments = try resolvingLUT(in: arguments)
    try perform { () throws(CommandError) in
      try editor.perform(CommandRegistry.command(named: name, arguments: arguments))
    }
    return .text(report(since: before))
  }

  /// The arguments with a grade's LUT and an effect's shader given by plugin name turned into
  /// their files' paths, and a shader that doesn't compile refused with its errors.
  private func resolvingLUT(in arguments: JSONValue) throws(ToolError) -> JSONValue {
    guard case .object(var fields) = arguments else {
      return arguments
    }
    if case .object(var grade) = fields["grade"], let lut = grade["lut"]?.stringValue {
      grade["lut"] = try .string(pluginFile(lut, kind: "LUT") { $0.lutPath(named: lut) })
      fields["grade"] = .object(grade)
    }
    if case .object(var effects) = fields["effects"], let shader = effects["shader"]?.stringValue {
      let path = try pluginFile(shader, kind: "shader") { $0.shaderPath(named: shader) }
      let context: RenderContext
      do {
        context = try player.renderContext()
      } catch {
        throw .engineFailed(error)
      }
      if let problem = context.shaderProblem(at: URL(filePath: path)) {
        throw .commandFailed(.invalidArguments("the shader doesn't compile: \(problem)"))
      }
      effects["shader"] = .string(path)
      fields["effects"] = .object(effects)
    }
    return .object(fields)
  }

  /// A file given by path, or a plugin's file of `kind` by name.
  private func pluginFile(
    _ name: String,
    kind: String,
    find: (PluginLibrary) -> String?,
  ) throws(ToolError) -> String {
    if name.hasPrefix("/") || name.hasPrefix("~") {
      return (name as NSString).expandingTildeInPath
    }
    guard let path = try find(host().plugins) else {
      throw .commandFailed(.invalidArguments(
        "there's no \(kind) called \(name); give a file's path or a \(kind) from list_plugins"
      ))
    }
    return path
  }

  /// Runs several registry commands as one undo step.
  private func batch(_ arguments: JSONValue) throws(ToolError) -> ToolResult {
    guard case .array(let edits) = arguments["edits"] else {
      throw rejected(.commandFailed(.invalidArguments("missing edits")), tool: "batch")
    }
    let before = editor.project
    let resolved = try edits.map { edit throws(ToolError) -> JSONValue in
      guard case .object(var fields) = edit, let arguments = fields["arguments"] else {
        return edit
      }
      fields["arguments"] = try resolvingLUT(in: arguments)
      return .object(fields)
    }
    try perform { () throws(CommandError) in
      var commands = [any Command]()
      for (index, edit) in resolved.enumerated() {
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
    let picture = media.isStill
      ? "a picture, \(media.width)×\(media.height), "
      : media.hasVideo ? "\(media.width)×\(media.height), " : "sound only, "
    return .text(
      "Imported \(media.name) as media \(media.id): \(media.duration.seconds) s, \(picture)"
        + "\(media.hasAudio ? "with" : "no") audio."
    )
  }

  /// Queues an export and says which files it makes.
  private func exportFiles(_ request: ExportArguments) throws(ToolError) -> ToolResult {
    let projectHost = try host()
    let timeline = editor.project.timeline
    let range: TimeRange? =
      if request.start != nil || request.end != nil {
        TimeRange(start: request.start ?? .zero, end: request.end ?? timeline.duration)
      } else {
        nil
      }
    let folder = request.folder.map { URL(filePath: ($0 as NSString).expandingTildeInPath) }
      ?? URL.moviesDirectory
    let files = try perform { () throws(CommandError) -> [String] in
      try projectHost.export(ExportRequest(
        kind: request.kind,
        folder: folder,
        name: request.name
          ?? projectHost.documentURL?.deletingPathExtension().lastPathComponent ?? "Shades",
        codec: request.codec ?? .hevc,
        time: request.at ?? .zero,
        range: range,
      ))
    }
    return .text("Exporting to \(folder.path): " + files.joined(separator: ", ")
      + ". get_jobs shows progress.")
  }

  /// Imports a plugin's sound (or a sound file) if it isn't yet, and places it on a free audio
  /// track, in one undo step.
  private func addSound(_ request: SoundArguments) async throws(ToolError) -> ToolResult {
    let url = try host().plugins.sound(named: request.sound)
      ?? (FileManager.default.fileExists(atPath: request.sound)
        ? URL(filePath: request.sound)
        : nil)
    guard let url else {
      throw .commandFailed(.invalidArguments(
        "there's no sound called \(request.sound); list_plugins shows the sounds"
      ))
    }
    var commands = [any Command]()
    let media: Media
    if let existing = editor.project.media.first(where: { $0.url == url }) {
      media = existing
    } else {
      do {
        media = try await MediaLoader.load(url)
      } catch {
        throw .mediaFailed(error)
      }
      commands.append(AddMedia(media: media))
    }
    guard media.hasAudio, !media.hasVideo else {
      throw .commandFailed(.invalidArguments("\(request.sound) isn't a sound-only file"))
    }
    commands.append(PlaceOnTop(mediaID: media.id, at: request.at, volume: request.volume))
    try perform { () throws(CommandError) in try editor.perform(commands, title: "Add Sound") }
    return .text(
      "Placed \(media.name) at \(request.at.seconds) s (\(media.duration.seconds) s long)."
    )
  }

  /// Saves the subject of one frame as a PNG in the project and imports it.
  private func cutoutFromFrame(_ request: CutoutFrameArguments) async throws(ToolError)
    -> ToolResult
  {
    guard let package = try host().documentURL else {
      throw .noProjectOpen
    }
    let timeline = editor.project.timeline
    guard
      let clip = timeline.clip(withID: request.clipID), clip.contains(request.at),
      let media = clip.mediaID.flatMap(editor.project.media(withID:)), media.hasVideo,
      !media.isStill
    else {
      throw .commandFailed(.invalidArguments("pick a moment inside a video clip"))
    }
    let destination = package.appending(path: "cache/stickers/\(UUID().uuidString).png")
    do {
      try await StickerMaker.cutout(
        from: media.url,
        at: clip.sourceTime(at: request.at).seconds,
        engine: request.engine.flatMap(MatteEngine.init(rawValue:)) ?? .visionPerson,
        to: destination,
      )
    } catch {
      throw .mattingFailed(error)
    }
    return try await importMedia(destination.path)
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
        context: player.renderContext(),
        mattes: player.mattes,
      )
      return ToolResult(content: [.png(png)])
    } catch {
      throw .engineFailed(error)
    }
  }

  /// The scopes of the frame at `seconds`, as a picture and in numbers.
  private func scopes(atSeconds seconds: Double) async throws(ToolError) -> ToolResult {
    do {
      let frame = try await FrameRenderer.image(
        of: editor.project,
        atSeconds: seconds,
        maxSide: 720,
        context: player.renderContext(),
        mattes: player.mattes,
      )
      let (picture, reading) = try Scopes.measure(frame)
      let percent = { (value: Double) in "\(Int((value * 100).rounded()))%" }
      let summary = "Scopes at \(seconds) s (waveform left, vectorscope right, RGB histogram "
        + "below). Average brightness \(percent(reading.averageBrightness)), highlights "
        + "clipped \(percent(reading.clippedHighlights)), shadows crushed "
        + "\(percent(reading.crushedShadows)), average saturation "
        + "\(percent(reading.averageSaturation))."
      return try ToolResult(content: [.text(summary), .png(FrameRenderer.pngData(from: picture))])
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

  /// The project host, with a project open (analysis needs one to save into).
  private func host() throws(ToolError) -> any ProjectHost {
    guard let projectHost else {
      throw noHost()
    }
    guard projectHost.documentURL != nil else {
      logger.error("tool.rejected reason=noProjectOpen")
      throw .noProjectOpen
    }
    return projectHost
  }

  private func queued(_ titles: [String], nothingLeft: String) -> ToolResult {
    guard !titles.isEmpty else {
      return .text(nothingLeft)
    }
    return .text("Queued:\n" + titles.lazy.map { "- " + $0 }
      .joined(separator: "\n") + "\nWatch with get_jobs.")
  }

  private func transcript(_ request: RangeArguments) throws(ToolError) -> ToolResult {
    let words = try editor.project.timeline.spokenWords(transcripts: host().analysis.transcripts)
      .filter { word in
        request.range.map { $0.start <= word.start && word.start < $0.end } ?? true
      }
    guard !words.isEmpty else {
      return .text(
        "No transcribed speech here. Run transcribe first (and wait for it in get_jobs)."
      )
    }
    if request.words == true {
      return .text(words.map { "\(format($0.start))–\(format($0.end)) \($0.text)" }
        .joined(separator: "\n"))
    }
    return .text(CaptionLayout.lines(for: words)
      .map { "\(format($0.start))–\(format($0.end)): \($0.text)" }
      .joined(separator: "\n"))
  }

  private func analysisReport() throws(ToolError) -> ToolResult {
    let analyses = try host().analysis.analyses
    let lines = editor.project.media.compactMap { media -> String? in
      guard let analysis = analyses[media.id] else {
        return nil
      }
      var parts = [String]()
      if let transcript = analysis.transcript {
        parts.append("transcript (\(transcript.language ?? "?"), \(transcript.words.count) words)")
      }
      if let speech = analysis.speech {
        let talking = speech.reduce(0) { $0 + $1.duration.seconds }
        parts
          .append(
            "speech in \(speech.count) stretches, \(format(MediaTime(seconds: talking))) s in all"
          )
      }
      if let beats = analysis.beats, !beats.beats.isEmpty {
        parts.append("beats at \(Int(beats.beatsPerMinute.rounded())) BPM")
      }
      if analysis.matte != nil {
        parts.append("cut-out")
      }
      if let tracks = analysis.tracks, !tracks.isEmpty {
        parts.append("tracked paths: " + tracks.keys.sorted().joined(separator: ", "))
      }
      return "- \(media.name) (\(media.id)): " + parts.joined(separator: "; ")
    }
    return .text(lines.isEmpty
      ? "Nothing analysed yet. Use transcribe and analyze_audio."
      : lines.joined(separator: "\n"))
  }

  /// The plugins in plain words, with what each offers and where its files are.
  private func pluginsReport() throws(ToolError) -> String {
    let projectHost = try host()
    let folders = projectHost.pluginFolders.urls.map(\.path).joined(separator: ", ")
    let plugins = projectHost.plugins.plugins
    guard !plugins.isEmpty else {
      return "No plugins yet. Plugin folders: \(folders). Make one by writing a folder with a "
        + "plugin.json (name, description, styles, templates) and stickers/, sounds/, fonts/."
    }
    var lines = ["Plugin folders: \(folders)"]
    for plugin in plugins {
      lines.append("\n\(plugin.name) (\(plugin.folder.path))" + (plugin.summary.isEmpty
          ? ""
          : ": \(plugin.summary)"))
      if let problem = plugin.problem {
        lines.append("  PROBLEM: \(problem)")
      }
      if !plugin.looks.isEmpty {
        lines.append("  looks: " + plugin.looks.keys.sorted().joined(separator: ", "))
      }
      if !plugin.shaders.isEmpty {
        lines.append("  shaders: " + plugin.shaders.keys.sorted().joined(separator: ", "))
      }
      if !plugin.luts.isEmpty {
        lines.append("  luts: " + plugin.luts.keys.sorted().joined(separator: ", "))
      }
      if !plugin.styles.isEmpty {
        lines.append("  styles: " + plugin.styles.keys.sorted().joined(separator: ", "))
      }
      for (name, template) in plugin.templates.sorted(by: { $0.key < $1.key }) {
        let fields = template.fields.isEmpty
          ? ""
          : " fields: " + template.fields.joined(separator: ", ")
        lines
          .append(
            "  template \(name): \(template.layers.count) layers, \(template.duration) s.\(fields)"
          )
      }
      for (kind, files) in [("stickers", plugin.stickers), ("sounds", plugin.sounds)]
        where !files.isEmpty
      {
        lines
          .append("  \(kind): " + files.sorted { $0.key < $1.key }.lazy
            .map { "\($0.key) (\($0.value.path))" }
            .joined(separator: ", "))
      }
      if !plugin.fonts.isEmpty {
        lines.append("  fonts: " + plugin.fonts.map(\.lastPathComponent).joined(separator: ", "))
      }
    }
    return lines.joined(separator: "\n")
  }

  /// A plan in plain words: counts per kind, then each item with its ID.
  private func describe(_ plan: PolishPlan) -> String {
    guard !plan.items.isEmpty else {
      return "Polish found nothing to change here."
    }
    let span = "\(format(plan.range.start))–\(format(plan.range.end)) s"
    var lines = ["Polish plan for \(plan.track), \(span) (shown on the timeline):"]
    for kind in PolishKind.allCases {
      let items = plan.items.filter { $0.kind == kind }
      guard !items.isEmpty else {
        continue
      }
      lines.append("\(kind.title) (\(items.count)):")
      lines += items
        .map { "- \($0.id) \(format($0.range.start))–\(format($0.range.end)) \($0.detail)" }
    }
    lines.append("Apply with polish_apply (all, or chosen item_ids / kinds), or polish_discard.")
    return lines.joined(separator: "\n")
  }

  private func format(_ time: MediaTime) -> String {
    String(format: "%.2f", time.seconds)
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
    case "add_sound": "Add Sound"
    case "export": "Export"
    case "undo": "Undo"
    case "redo": "Redo"
    case "batch": "Batch of Edits"
    default: CommandRegistry.tools.first { $0.name == name }?.title ?? name
    }
  }

  /// Runs project work, wrapping its error for MCP. (Commands log their own rejections.)
  private func perform<T>(_ work: () throws(CommandError) -> T) throws(ToolError) -> T {
    do {
      return try work()
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

// MARK: - TranscribeArguments

private struct TranscribeArguments: Decodable {
  let mediaIDs: [UUID]?
  let model: String?
  let language: String?
}

// MARK: - MediaListArguments

private struct MediaListArguments: Decodable {
  let mediaIDs: [UUID]?
}

// MARK: - RangeArguments

private struct RangeArguments: Decodable {
  let start: MediaTime?
  let end: MediaTime?
  let words: Bool?

  /// The stretch asked for, open-ended on either side.
  var range: TimeRange? {
    guard start != nil || end != nil else {
      return nil
    }
    return TimeRange(start: start ?? .zero, end: end ?? MediaTime(seconds: 1_000_000))
  }
}

extension TranscriptionModel {
  /// The model Claude names: "base", "small" or "large_turbo".
  fileprivate init?(argument: String) {
    switch argument {
    case "base": self = .base
    case "small": self = .small
    case "large_turbo": self = .largeTurbo
    default: return nil
    }
  }
}

// MARK: - PolishArguments

private struct PolishArguments: Decodable {
  let start: MediaTime
  let end: MediaTime
  let track: String?
  let silences: Bool?
  let fillers: Bool?
  let retakes: Bool?
  let beatSnap: Bool?
  let punchIn: Bool?
  let minSilence: Double?

  var range: TimeRange {
    TimeRange(start: start, end: end)
  }

  var options: PolishOptions {
    PolishOptions(
      silences: silences ?? true,
      fillers: fillers ?? true,
      retakes: retakes ?? true,
      beatSnap: beatSnap ?? true,
      punchIn: punchIn ?? true,
      minimumSilence: minSilence ?? 0.6,
    )
  }
}

// MARK: - PolishApplyArguments

private struct PolishApplyArguments: Decodable {
  let itemIDs: [UUID]?
  let kinds: [String]?
}

// MARK: - CutoutArguments

private struct CutoutArguments: Decodable {
  let mediaIDs: [UUID]?
  let engine: String?
}

// MARK: - CaptionArguments

private struct CaptionArguments: Decodable {
  let start: MediaTime?
  let end: MediaTime?
  let reveal: TextReveal?
  let style: TextStyle?

  /// The stretch asked for, open-ended on either side.
  var range: TimeRange? {
    RangeArguments(start: start, end: end, words: nil).range
  }
}

// MARK: - CutoutFrameArguments

private struct CutoutFrameArguments: Decodable {
  let clipID: UUID
  let at: MediaTime
  let engine: String?
}

// MARK: - TemplateArguments

private struct TemplateArguments: Decodable {
  let name: String
  let at: MediaTime
  let fields: [String: String]?
}

// MARK: - LoudnessArguments

private struct LoudnessArguments: Decodable {
  let target: Double?
}

// MARK: - NoiseArguments

private struct NoiseArguments: Decodable {
  let clipIDs: [UUID]
  let strength: Double?
}

// MARK: - DuckArguments

private struct DuckArguments: Decodable {
  let track: String?
  let level: Double?
}

// MARK: - ExportArguments

private struct ExportArguments: Decodable {
  let kind: ExportKind
  let name: String?
  let folder: String?
  let codec: VideoCodec?
  let at: MediaTime?
  let start: MediaTime?
  let end: MediaTime?
}

// MARK: - SoundArguments

private struct SoundArguments: Decodable {
  let sound: String
  let at: MediaTime
  let volume: Double?
}

// MARK: - LookArguments

private struct LookArguments: Decodable {
  let clipIDs: [UUID]
  let look: String
}

// MARK: - StyleArguments

private struct StyleArguments: Decodable {
  let clipIDs: [UUID]
  let style: String
}

// MARK: - TrackArguments

private struct TrackArguments: Decodable {
  struct Box: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
  }

  let clipID: UUID
  let at: MediaTime
  let box: Box
  let name: String
}

// MARK: - FollowArguments

private struct FollowArguments: Decodable {
  let clipID: UUID
  let targetID: UUID
  let path: String?
}

// MARK: - ClipListArguments

private struct ClipListArguments: Decodable {
  let clipIDs: [UUID]?
}

// MARK: - SeekArguments

private struct SeekArguments: Decodable {
  let seconds: Double
}
