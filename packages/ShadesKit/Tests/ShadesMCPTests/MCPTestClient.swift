import Foundation
import ShadesCommands
import Testing

// MARK: - MCPTestClient

/// Talks to a running MCPServer over real HTTP, the way Claude Code does.
struct MCPTestClient {

  let port: UInt16

  /// Sends a raw HTTP request and returns the status code and body.
  func send(
    method: String = "POST",
    path: String = "/mcp",
    body: Data = Data(),
    headers: [String: String] = ["Content-Type": "application/json"],
  ) async throws -> (status: Int, body: Data) {
    var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(port)\(path)")))
    request.httpMethod = method
    request.httpBody = body
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
  }

  /// Calls a JSON-RPC method and returns the reply.
  func rpc(_ method: String, params: JSONValue = [:]) async throws -> JSONValue {
    let message: JSONValue = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": .string(method),
      "params": params,
    ]
    let reply = try await send(body: message.jsonData())
    return try JSONValue(data: reply.body)
  }

  /// Calls a tool and returns its result object.
  func tool(_ name: String, _ arguments: JSONValue = [:]) async throws -> JSONValue {
    let reply = try await rpc("tools/call", params: ["name": .string(name), "arguments": arguments])
    return try #require(reply["result"])
  }

}

extension JSONValue {
  /// The text of a tool result's first block.
  var resultText: String {
    guard case .array(let content) = self["content"] else {
      return ""
    }
    return content.first?["text"]?.stringValue ?? ""
  }

  /// Whether a tool result is an error.
  var isErrorResult: Bool {
    self["isError"] == true
  }
}
