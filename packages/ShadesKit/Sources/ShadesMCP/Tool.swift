import ShadesCommands

// MARK: - Tool

/// A tool Claude can call: its name, what it does, and the arguments it takes.
struct Tool: Sendable {
  let name: String
  let summary: String
  let parameters: JSONValue
  let kind: ToolKind

  /// The `tools/list` entry.
  var listing: JSONValue {
    [
      "name": .string(name),
      "description": .string(summary),
      "inputSchema": parameters,
      "annotations": ["readOnlyHint": .bool(kind == .read)],
    ]
  }
}

// MARK: - ToolKind

/// What a tool does, which decides whether it's an undo step and a History entry.
enum ToolKind: Sendable {
  /// Only looks: reads, renders or moves the playhead.
  case read
  /// Changes the project: one undo step and one History entry.
  case edit
  /// Lists, creates or opens projects.
  case project
}
