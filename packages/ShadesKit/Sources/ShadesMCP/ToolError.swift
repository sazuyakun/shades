import Foundation
import ShadesCommands
import ShadesEngine
import ShadesMedia

// MARK: - ToolError

/// Why a Claude tool call failed. Named `ToolError` because the MCP library owns `MCPError`.
public enum ToolError: Error, Equatable {
  case unknownTool(String)
  case missingArgument(String)
  case invalidArgument(String)
  case commandFailed(CommandError)
  case mediaFailed(MediaError)
  case engineFailed(EngineError)
  case listenFailed(port: UInt16)
}

// MARK: LocalizedError

extension ToolError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unknownTool(let name):
      "There's no tool called \(name)."
    case .missingArgument(let name):
      "The \(name) argument is required."
    case .invalidArgument(let name):
      "The \(name) argument has the wrong type or value."
    case .commandFailed(let error):
      error.errorDescription
    case .mediaFailed(let error):
      error.errorDescription
    case .engineFailed(let error):
      error.errorDescription
    case .listenFailed(let port):
      "Shades couldn't listen for Claude on port \(port). Is another copy of Shades open?"
    }
  }
}
