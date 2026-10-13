import Foundation
import Network
import OSLog

/// The relay logger. Log failures once, where they happen (see /CLAUDE.md, Logging).
let logger = Logger(subsystem: "com.sazuyakun.shades", category: "Relay")

// MARK: - Relay

/// Connects Claude, which speaks MCP over stdin/stdout, to the MCP server inside Shades.app.
/// It only passes bytes both ways; every tool lives in ShadesMCP.
@main
enum Relay {

  // MARK: Internal

  /// Must match `MCPServer.port` in ShadesMCP.
  static let port: NWEndpoint.Port = 4747

  static func main() {
    let connection = NWConnection(host: .ipv4(.loopback), port: port, using: .tcp)
    connection.stateUpdateHandler = { state in
      MainActor.assumeIsolated {
        switch state {
        case .ready:
          forwardInput(to: connection)
          forwardOutput(from: connection)

        case .waiting,
             .failed:
          logger.error("relay.connectFailed port=\(port.rawValue, privacy: .public)")
          FileHandle.standardError
            .write(Data("Shades isn't running. Open Shades, then try again.\n".utf8))
          exit(1)

        default:
          break
        }
      }
    }
    connection.start(queue: .main)
    dispatchMain()
  }

  // MARK: Private

  /// Sends everything Claude writes to stdin on to Shades. Exits when Claude closes stdin.
  private static func forwardInput(to connection: NWConnection) {
    FileHandle.standardInput.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        exit(0)
      }
      connection.send(content: data, completion: .idempotent)
    }
  }

  /// Writes everything Shades sends to stdout for Claude. Exits when Shades disconnects.
  private static func forwardOutput(from connection: NWConnection) {
    connection
      .receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
        MainActor.assumeIsolated {
          if let data, !data.isEmpty {
            FileHandle.standardOutput.write(data)
          }
          guard !isComplete, error == nil else {
            exit(0)
          }
          forwardOutput(from: connection)
        }
      }
  }

}
