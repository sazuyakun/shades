import Network
import ShadesCommands
import ShadesEngine
import ShadesMCP
import Testing

@MainActor
struct MCPServerTests {
  @Test
  func `the server accepts connections on localhost`() async throws {
    let server = MCPServer(editor: Editor(), player: Player(), port: 47_471)
    try server.start()
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
}
