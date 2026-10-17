import ShadesCommands

/// A tool Claude can call: its name, what it does, and the arguments it takes.
struct Tool: Sendable {
  let name: String
  let summary: String
  let parameters: JSONValue
  /// Tools that only look (read or render) are marked so Claude can call them freely.
  let isReadOnly: Bool

  /// The `tools/list` entry.
  var listing: JSONValue {
    [
      "name": .string(name),
      "description": .string(summary),
      "inputSchema": parameters,
      "annotations": ["readOnlyHint": .bool(isReadOnly)],
    ]
  }
}
