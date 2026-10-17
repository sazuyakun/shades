import Foundation
import ShadesCommands

// MARK: - ToolResult

/// What a tool call sends back. A failed call is still a result (with `isError`), so Claude can
/// read the message and try again.
public struct ToolResult: Sendable, Hashable {

  // MARK: Lifecycle

  init(content: [ToolContent], isError: Bool = false) {
    self.content = content
    self.isError = isError
  }

  // MARK: Public

  public let content: [ToolContent]
  public let isError: Bool

  /// The text parts, joined, as shown in the History pane.
  public var text: String {
    content.compactMap { part in
      if case .text(let text) = part {
        return text
      }
      return nil
    }
    .joined(separator: " ")
  }

  // MARK: Internal

  /// The MCP wire form.
  var json: JSONValue {
    ["content": .array(content.map(\.json)), "isError": .bool(isError)]
  }

  /// A successful text result.
  static func text(_ text: String) -> ToolResult {
    ToolResult(content: [.text(text)])
  }

  /// A failed result carrying the plain-words message.
  static func failure(_ message: String) -> ToolResult {
    ToolResult(content: [.text(message)], isError: true)
  }

}

// MARK: - ToolContent

/// One block of a tool result.
public enum ToolContent: Sendable, Hashable {
  case text(String)
  case png(Data)

  /// The MCP wire form.
  var json: JSONValue {
    switch self {
    case .text(let text):
      ["type": "text", "text": .string(text)]
    case .png(let data):
      ["type": "image", "data": .string(data.base64EncodedString()), "mimeType": "image/png"]
    }
  }
}
