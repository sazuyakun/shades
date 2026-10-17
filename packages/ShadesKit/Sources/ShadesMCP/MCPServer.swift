import MCP
import Network
import Observation
import ShadesCommands
import ShadesEngine

/// Listens on localhost for Claude (through the `apps/mcp` relay) and serves Shades' tools.
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

  /// The local port the relay connects to. Must match `Relay.port` in apps/mcp.
  public static let defaultPort: UInt16 = 4747

  public let port: UInt16
  /// What Claude has changed this session, for the History pane.
  public let activity = ActivityLog()
  public private(set) var status = ServerStatus.starting

  /// Starts accepting connections from Claude, on localhost only. The outcome shows in `status`.
  public func start() {
    let number = port
    let parameters = NWParameters.tcp
    // why: binding through the required endpoint (not `NWListener(using:on:)`, which rejects a
    // port given twice) keeps the server reachable from this Mac only.
    parameters.requiredLocalEndpoint = .hostPort(
      host: .ipv4(.loopback),
      port: NWEndpoint.Port(integerLiteral: number),
    )
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

        case .failed(let reason):
          logger
            .error(
              "listen.failed port=\(number, privacy: .public) error=\(reason, privacy: .public)"
            )
          self?.status = .failed(.listenFailed(port: number))

        default:
          break
        }
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      Task { @MainActor in
        await self?.serve(connection)
      }
    }
    listener.start(queue: .main)
    self.listener = listener
  }

  // MARK: Private

  @ObservationIgnored private let handler: ToolHandler
  @ObservationIgnored private var listener: NWListener?

  /// Runs one MCP session for one connected client until it disconnects.
  private func serve(_ connection: NWConnection) async {
    let server = Server(
      name: "Shades",
      version: "0.1.0",
      capabilities: .init(tools: .init(listChanged: false)),
    )
    let handler = handler
    await server.withMethodHandler(ListTools.self) { _ in
      ListTools.Result(tools: ToolHandler.tools)
    }
    await server.withMethodHandler(CallTool.self) { parameters in
      await handler.call(parameters)
    }
    let transport = NetworkTransport(
      connection: connection,
      heartbeatConfig: .disabled,
      reconnectionConfig: .disabled,
    )
    do {
      try await server.start(transport: transport)
      await server.waitUntilCompleted()
    } catch {
      logger.error("session.failed error=\(error, privacy: .public)")
    }
  }

}
