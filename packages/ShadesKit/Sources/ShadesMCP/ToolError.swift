import Foundation
import ShadesCommands
import ShadesEngine
import ShadesMedia

// MARK: - ToolError

/// Why a Claude tool call failed, or why Claude can't connect.
public enum ToolError: Error, Equatable {
  case commandFailed(CommandError)
  case mediaFailed(MediaError)
  case engineFailed(EngineError)
  case listenFailed(port: UInt16)
}

// MARK: LocalizedError

extension ToolError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .commandFailed(let error):
      error.errorDescription
    case .mediaFailed(let error):
      error.errorDescription
    case .engineFailed(let error):
      error.errorDescription
    case .listenFailed(let port):
      "Claude can't connect: port \(port) is already in use, usually by another copy of "
        + "Shades. Quit it, then reopen Shades."
    }
  }
}
