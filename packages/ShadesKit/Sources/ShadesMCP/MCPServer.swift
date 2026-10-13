import MCP
import Network
import ShadesCommands
import ShadesEngine

/// Listens on localhost for Claude (through the `apps/mcp` relay) and serves Shades' tools.
@MainActor
public final class MCPServer {

  // MARK: Lifecycle

  public init(editor: Editor, player: Player, port: UInt16 = defaultPort) {
    handler = ToolHandler(editor: editor, player: player)
    self.port = port
  }

  // MARK: Public

  /// The local port the relay connects to. Must match `Relay.port` in apps/mcp.
  public static let defaultPort: UInt16 = 4747

  public let port: UInt16

  /// Starts accepting connections from Claude, on localhost only.
  public func start() throws(ToolError) {
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
      logger.error("server.listenFailed port=\(number, privacy: .public)")
      throw .listenFailed(port: number)
    }
    listener.stateUpdateHandler = { state in
      if case .failed(let error) = state {
        logger
          .error(
            "server.listenFailed port=\(number, privacy: .public) error=\(error, privacy: .public)"
          )
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

  private let handler: ToolHandler
  private var listener: NWListener?

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
