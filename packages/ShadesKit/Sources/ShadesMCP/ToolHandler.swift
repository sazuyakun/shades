import Foundation
import MCP
import ShadesCommands
import ShadesCore
import ShadesEngine
import ShadesMedia

/// Shades' actions as Claude tools: what each tool is called, and what it does when called.
@MainActor
public struct ToolHandler {

  // MARK: Lifecycle

  public init(editor: Editor, player: Player) {
    self.editor = editor
    self.player = player
  }

  // MARK: Public

  /// Every tool Claude can see.
  public nonisolated static let tools: [Tool] = [
    Tool(
      name: "get_project",
      description: "Get the whole project as JSON: imported media and the timeline's tracks "
        + "and clips. Times are exact fractions: seconds = value / timescale.",
      inputSchema: schema([:]),
    ),
    Tool(
      name: "import_media",
      description: "Import a video file from disk into the project. Returns its media ID.",
      inputSchema: schema(["path": ("string", "Absolute path to the video file")]),
    ),
    Tool(
      name: "append_clip",
      description: "Place a whole imported media file at the end of the timeline.",
      inputSchema: schema(["media_id": ("string", "ID returned by import_media")]),
    ),
    Tool(name: "play", description: "Start playback in the viewer.", inputSchema: schema([:])),
    Tool(name: "pause", description: "Pause playback.", inputSchema: schema([:])),
    Tool(
      name: "seek",
      description: "Move the playhead to a time on the timeline.",
      inputSchema: schema(["seconds": ("number", "Time on the timeline, in seconds")]),
    ),
    Tool(
      name: "render_frame",
      description: "Render the timeline at a time and return it as an image, to check the look.",
      inputSchema: schema(["seconds": ("number", "Time on the timeline, in seconds")]),
    ),
  ]

  /// Runs a tool call. Failures come back as an error result Claude can read and act on.
  public func call(_ parameters: CallTool.Parameters) async -> CallTool.Result {
    do {
      return try await run(parameters)
    } catch {
      return CallTool.Result(
        content: [.text(
          text: error.errorDescription ?? "The tool failed.",
          annotations: nil,
          _meta: nil,
        )],
        isError: true,
      )
    }
  }

  // MARK: Private

  private let editor: Editor
  private let player: Player

  /// A JSON Schema object with the given required properties: name → (type, description).
  private nonisolated static func schema(_ properties: [String: (
    type: String,
    description: String,
  )]) -> Value {
    .object([
      "type": "object",
      "properties": .object(properties.mapValues { property in
        .object(["type": .string(property.type), "description": .string(property.description)])
      }),
      "required": .array(properties.keys.sorted().map { .string($0) }),
    ])
  }

  private func run(_ parameters: CallTool.Parameters) async throws(ToolError) -> CallTool.Result {
    switch parameters.name {
    case "get_project":
      return text(projectJSON())

    case "import_media":
      return try await importMedia(at: string("path", in: parameters))

    case "append_clip":
      return try appendClip(mediaID: string("media_id", in: parameters))

    case "play":
      player.play()
      return text("Playing.")

    case "pause":
      player.pause()
      return text("Paused at \(player.currentTime) seconds.")

    case "seek":
      let seconds = try number("seconds", in: parameters)
      await player.seek(toSeconds: seconds)
      return text("Playhead at \(player.currentTime) seconds.")

    case "render_frame":
      return try await renderFrame(atSeconds: number("seconds", in: parameters))

    default:
      logger.error("tool.failed reason=unknownTool name=\(parameters.name, privacy: .public)")
      throw .unknownTool(parameters.name)
    }
  }

  private func importMedia(at path: String) async throws(ToolError) -> CallTool.Result {
    let media: Media
    do {
      media = try await MediaLoader.load(URL(fileURLWithPath: path))
    } catch {
      throw .mediaFailed(error)
    }
    do {
      try editor.perform(AddMedia(media: media))
    } catch {
      throw .commandFailed(error)
    }
    return text(
      "Imported \(media.name) as media \(media.id): \(media.duration.seconds) s, "
        + "\(media.width)×\(media.height), \(media.hasAudio ? "with" : "no") audio."
    )
  }

  private func appendClip(mediaID: String) throws(ToolError) -> CallTool.Result {
    guard let id = UUID(uuidString: mediaID) else {
      logger.error("tool.failed reason=invalidArgument name=media_id")
      throw .invalidArgument("media_id")
    }
    do {
      try editor.perform(AppendClip(mediaID: id))
    } catch {
      throw .commandFailed(error)
    }
    return text(
      "Appended. The timeline is now \(editor.project.timeline.duration.seconds) seconds long."
    )
  }

  private func renderFrame(atSeconds seconds: Double) async throws(ToolError) -> CallTool.Result {
    let png: Data
    do {
      png = try await FrameRenderer.png(of: editor.project, atSeconds: seconds, maxSide: 768)
    } catch {
      throw .engineFailed(error)
    }
    return CallTool.Result(
      content: [.image(
        data: png.base64EncodedString(),
        mimeType: "image/png",
        annotations: nil,
        _meta: nil,
      )]
    )
  }

  private func projectJSON() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
      return try String(decoding: encoder.encode(editor.project), as: UTF8.self)
    } catch {
      logger.fault("project.encodeFailed")
      assertionFailure("Project failed to encode as JSON")
      return "{}"
    }
  }

  private func string(
    _ name: String,
    in parameters: CallTool.Parameters,
  ) throws(ToolError) -> String {
    guard let value = parameters.arguments?[name]?.stringValue else {
      logger.error("tool.failed reason=missingArgument name=\(name, privacy: .public)")
      throw .missingArgument(name)
    }
    return value
  }

  /// Reads a number argument, accepting both `5` and `5.0`.
  private func number(
    _ name: String,
    in parameters: CallTool.Parameters,
  ) throws(ToolError) -> Double {
    let value = parameters.arguments?[name]
    guard let number = value?.doubleValue ?? value?.intValue.map(Double.init) else {
      logger.error("tool.failed reason=missingArgument name=\(name, privacy: .public)")
      throw .missingArgument(name)
    }
    return number
  }

  private func text(_ message: String) -> CallTool.Result {
    CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)])
  }

}
