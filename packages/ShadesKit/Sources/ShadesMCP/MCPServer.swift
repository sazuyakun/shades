import Foundation
import Network
import Observation
import ShadesCommands
import ShadesEngine

/// Shades' MCP server: Streamable HTTP on `http://127.0.0.1:4747/mcp`, reachable from this Mac
/// only. Claude Code connects with `claude mcp add --transport http shades <endpoint>`.
/// Its `status` tells the UI whether Claude can connect.
@MainActor
@Observable
public final class MCPServer {

  // MARK: Lifecycle

  public init(editor: Editor, player: Player, port: UInt16 = defaultPort) {
    handler = ToolHandler(editor: editor, player: player, activity: activity)
    self.port = port
  }

  // MARK: Public

  public static let defaultPort: UInt16 = 4747

  public let port: UInt16
  /// What Claude has changed this session, for the History pane.
  public let activity = ActivityLog()
  public private(set) var status = ServerStatus.starting

  /// The URL Claude connects to.
  public var endpoint: String {
    "http://127.0.0.1:\(port)\(MCPEndpoint.path)"
  }

  /// The one-time command that connects Claude Code to Shades.
  public var connectCommand: String {
    "claude mcp add --transport http shades \(endpoint)"
  }

  /// Starts accepting connections from Claude. The outcome shows in `status`.
  public func start() {
    let number = port
    let parameters = NWParameters.tcp
    // why: binding through the required endpoint (not `NWListener(using:on:)`, which rejects a
    // port given twice) keeps the server reachable from this Mac only.
    parameters.requiredLocalEndpoint = .hostPort(
      host: .ipv4(.loopback),
      port: NWEndpoint.Port(integerLiteral: number),
    )
    parameters.allowLocalEndpointReuse = true
    let listener: NWListener
    do {
      listener = try NWListener(using: parameters)
    } catch {
      logger.error("listen.failed port=\(number, privacy: .public)")
      status = .failed(.listenFailed(port: number))
      return
    }
    listener.stateUpdateHandler = { [weak self] state in
      MainActor.assumeIsolated {
        switch state {
        case .ready:
          self?.status = .ready

        case .failed(let reason),
             .waiting(let reason):
          logger
            .error(
              "listen.failed port=\(number, privacy: .public) error=\(reason, privacy: .public)"
            )
          self?.status = .failed(.listenFailed(port: number))
          self?.listener?.cancel()

        default:
          break
        }
      }
    }
    let endpoint = MCPEndpoint(handler: handler, port: number)
    let queue = connectionQueue
    listener.newConnectionHandler = { connection in
      let served = HTTPConnection(connection: connection, queue: queue) { request in
        await endpoint.response(for: request)
      }
      Task { await served.start() }
    }
    listener.start(queue: .main)
    self.listener = listener
  }

  /// Stops listening; connections being served finish on their own.
  public func stop() {
    listener?.cancel()
    listener = nil
  }

  // MARK: Private

  @ObservationIgnored private let handler: ToolHandler
  @ObservationIgnored private var listener: NWListener?
  @ObservationIgnored private let connectionQueue = DispatchQueue(label: "com.sazuyakun.shades.mcp")

}
