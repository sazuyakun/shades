import ShadesCore

// MARK: - Command

/// A single edit to the project. Buttons, shortcuts, the palette and Claude all change the
/// project only through commands.
public protocol Command: Sendable {
  /// What the edit is called in Undo and the History pane, e.g. "Split Clip".
  static var title: String { get }

  /// Applies the edit, or throws and leaves the project unchanged.
  func apply(to project: inout Project) throws(CommandError)
}

// MARK: - ToolCommand

/// A command Claude can call by name, with arguments decoded from its JSON. Field names are
/// sent in `snake_case` (`clip_id`), times as plain seconds.
public protocol ToolCommand: Command, Decodable {
  /// The tool name, e.g. `split_clip`.
  static var name: String { get }
  /// What the tool does, written for Claude.
  static var summary: String { get }
  /// A JSON Schema of the arguments.
  static var parameters: JSONValue { get }
}
