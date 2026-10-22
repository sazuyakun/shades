import Foundation
import ShadesCommands
import ShadesEngine
import ShadesMCP
import ShadesTestSupport
import Testing

@MainActor
@Suite(.serialized)
struct MCPServerTests {

  // MARK: Internal

  @Test
  func `initialize answers with the guide`() async throws {
    let (server, client) = try await running(port: 47_471)
    defer { server.stop() }
    let reply = try await client.rpc("initialize", params: ["protocolVersion": "2025-06-18"])
    #expect(reply["result"]?["protocolVersion"] == "2025-06-18")
    #expect(reply["result"]?["instructions"]?.stringValue?.contains("4:3") == true)
  }

  @Test
  func `tools list includes the built-ins and every command`() async throws {
    let (server, client) = try await running(port: 47_472)
    defer { server.stop() }
    let reply = try await client.rpc("tools/list")
    guard case .array(let tools) = reply["result"]?["tools"] else {
      Issue.record("no tools")
      return
    }
    let names = Set(tools.compactMap { $0["name"]?.stringValue })
    #expect(names.isSuperset(of: ["get_project", "render_frame", "batch", "undo"]))
    #expect(names.isSuperset(of: CommandRegistry.tools.map { $0.name }))
  }

  @Test
  func `only POST to mcp from this Mac is served`() async throws {
    let (server, client) = try await running(port: 47_473)
    defer { server.stop() }
    #expect(try await client.send(method: "GET").status == 405)
    #expect(try await client.send(path: "/other").status == 404)
    let foreign = try await client.send(headers: ["Origin": "https://evil.example"])
    #expect(foreign.status == 403)
    #expect(try await client.send(body: Data("not json".utf8)).status == 400)
  }

  @Test
  func `a notification is accepted without a reply`() async throws {
    let (server, client) = try await running(port: 47_474)
    defer { server.stop() }
    let message: JSONValue = ["jsonrpc": "2.0", "method": "notifications/initialized"]
    #expect(try await client.send(body: message.jsonData()).status == 202)
  }

  @Test
  func `a second server on the same port reports why it failed`() async throws {
    let (first, _) = try await running(port: 47_475)
    defer { first.stop() }
    let second = MCPServer(editor: Editor(), player: Player(), port: 47_475)
    second.start()
    await waitUntilSettled(second)
    #expect(second.status == .failed(.listenFailed(port: 47_475)))
  }

  // MARK: Private

  /// Starts a server on `port` and waits until it's ready.
  private func running(port: UInt16) async throws -> (MCPServer, MCPTestClient) {
    let server = MCPServer(editor: Editor(), player: Player(), port: port)
    server.start()
    await waitUntilSettled(server)
    try #require(server.status == .ready)
    return (server, MCPTestClient(port: port))
  }

  /// Waits (up to 2 s) for a server to leave `.starting`.
  private func waitUntilSettled(_ server: MCPServer) async {
    for _ in 0 ..< 200 where server.status == .starting {
      try? await Task.sleep(for: .milliseconds(10)) // why: a cancelled sleep just checks again.
    }
  }

}
