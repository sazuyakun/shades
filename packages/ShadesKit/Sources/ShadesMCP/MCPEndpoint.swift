import Foundation
import ShadesCommands

/// `POST /mcp`: checks the HTTP rules of the Streamable HTTP transport (stateless JSON mode),
/// then answers one JSON-RPC message. Ported from Nebula's router and dispatcher.
///
/// HTTP rules, in order: `Host` must be this Mac (blocks DNS rebinding), an `Origin` if sent
/// must be this Mac, only `POST /mcp` exists, and the body must be JSON.
struct MCPEndpoint: Sendable {

  // MARK: Internal

  /// The only path served.
  static let path = "/mcp"
  /// Protocol revisions spoken, newest first.
  static let protocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

  let handler: ToolHandler
  let port: UInt16

  func response(for request: HTTPRequest) async -> HTTPResponse {
    let hosts: Set = ["127.0.0.1:\(port)", "localhost:\(port)"]
    guard let host = request.header("host")?.lowercased(), hosts.contains(host) else {
      return .plain(status: 403, "Forbidden: invalid Host header.")
    }
    if
      let origin = request.header("origin")?.lowercased(),
      !hosts.contains(origin.replacing("http://", with: ""))
    {
      return .plain(status: 403, "Forbidden: invalid Origin header.")
    }
    guard request.path == Self.path else {
      return .plain(status: 404, "Not found. The MCP endpoint is POST \(Self.path).")
    }
    guard request.method == "POST" else {
      return .plain(status: 405, "Method not allowed. Use POST.", headers: ["Allow": "POST"])
    }
    if let type = request.header("content-type"), !type.lowercased().contains("application/json") {
      return .plain(status: 415, "Content-Type must be application/json.")
    }
    guard let message = try? JSONValue(data: request.body) else {
      // why: a body that isn't JSON is the client's mistake, answered with a parse error.
      return reply(error(id: .null, code: -32700, "Parse error"), status: 400)
    }
    return await answer(message)
  }

  // MARK: Private

  private func answer(_ message: JSONValue) async -> HTTPResponse {
    guard case .object(let object) = message, object["jsonrpc"] == "2.0" else {
      return reply(error(id: .null, code: -32600, "Send one JSON-RPC 2.0 object"), status: 400)
    }
    guard let method = object["method"]?.stringValue else {
      // A response to a request we never send, or junk: nothing to answer.
      return HTTPResponse(status: 202)
    }
    guard let id = object["id"], id != .null else {
      return HTTPResponse(status: 202)
    }
    let params = object["params"] ?? [:]
    switch method {
    case "initialize":
      return reply(result(id: id, initializeResult(params)))

    case "ping":
      return reply(result(id: id, [:]))

    case "tools/list":
      let tools = await handler.tools.map(\.listing)
      return reply(result(id: id, ["tools": .array(tools)]))

    case "tools/call":
      guard let name = params["name"]?.stringValue else {
        return reply(error(id: id, code: -32602, "Missing tool name"))
      }
      let toolResult = await handler.call(name, arguments: params["arguments"] ?? [:])
      return reply(result(id: id, toolResult.json))

    default:
      return reply(error(id: id, code: -32601, "Method not found: \(method)"))
    }
  }

  private func initializeResult(_ params: JSONValue) -> JSONValue {
    let requested = params["protocolVersion"]?.stringValue ?? ""
    let version = Self.protocolVersions.contains(requested) ? requested : Self.protocolVersions[0]
    return [
      "protocolVersion": .string(version),
      "capabilities": ["tools": ["listChanged": false]],
      "serverInfo": ["name": "shades", "version": "0.2.0"],
      "instructions": .string(Guide.text),
    ]
  }

  private func result(id: JSONValue, _ result: JSONValue) -> JSONValue {
    ["jsonrpc": "2.0", "id": id, "result": result]
  }

  private func error(id: JSONValue, code: Int, _ message: String) -> JSONValue {
    [
      "jsonrpc": "2.0",
      "id": id,
      "error": ["code": .number(Double(code)), "message": .string(message)],
    ]
  }

  private func reply(_ message: JSONValue, status: Int = 200) -> HTTPResponse {
    do {
      return try .json(message.jsonData(), status: status)
    } catch {
      logger.fault("reply.encodeFailed")
      assertionFailure("A JSON-RPC reply failed to encode")
      return .plain(status: 500, "Could not encode the response.")
    }
  }

}
