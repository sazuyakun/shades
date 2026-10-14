import Network
import ShadesCommands
import ShadesEngine
import ShadesMCP
import Testing

@MainActor
struct MCPServerTests {

  // MARK: Internal

  @Test
  func `the server accepts connections on localhost`() async {
    let server = MCPServer(editor: Editor(), player: Player(), port: 47_471)
    server.start()
    let connection = NWConnection(host: .ipv4(.loopback), port: 47_471, using: .tcp)
    let connected = await withCheckedContinuation { continuation in
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          continuation.resume(returning: true)
          connection.stateUpdateHandler = nil

        case .failed,
             .waiting:
          continuation.resume(returning: false)
          connection.stateUpdateHandler = nil

        default:
          break
        }
      }
      connection.start(queue: .main)
    }
    connection.cancel()
    #expect(connected)
  }

  @Test
  func `a server reports ready, and a second one on the same port reports why it failed`() async {
    let first = MCPServer(editor: Editor(), player: Player(), port: 47_472)
    let second = MCPServer(editor: Editor(), player: Player(), port: 47_472)
    first.start()
    await waitUntilSettled(first)
    second.start()
    await waitUntilSettled(second)
    #expect(first.status == .ready)
    #expect(second.status == .failed(.listenFailed(port: 47_472)))
  }

  // MARK: Private

  /// Waits (up to 2 s) for a server to leave `.starting`.
  private func waitUntilSettled(_ server: MCPServer) async {
    for _ in 0 ..< 200 where server.status == .starting {
      try? await Task.sleep(for: .milliseconds(10)) // why: a cancelled sleep just checks again.
    }
  }

}
