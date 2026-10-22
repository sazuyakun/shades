import Foundation
import ShadesCommands

// MARK: - MCPTestClient

/// Talks to a running MCPServer over real HTTP, the way Claude Code does.
public struct MCPTestClient: Sendable {

  // MARK: Lifecycle

  public init(port: UInt16) {
    self.port = port
  }

  // MARK: Public

  public let port: UInt16

  /// Sends a raw HTTP request and returns the status code and body.
  public func send(
    method: String = "POST",
    path: String = "/mcp",
    body: Data = Data(),
    headers: [String: String] = ["Content-Type": "application/json"],
  ) async throws(FixtureError) -> (status: Int, body: Data) {
    guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else {
      throw .requestFailed
    }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    } catch {
      throw .requestFailed
    }
  }

  /// Calls a JSON-RPC method and returns the reply.
  public func rpc(_ method: String, params: JSONValue = [:]) async throws(FixtureError)
    -> JSONValue
  {
    let message: JSONValue = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": .string(method),
      "params": params,
    ]
    do {
      let reply = try await send(body: message.jsonData())
      return try JSONValue(data: reply.body)
    } catch {
      throw .requestFailed
    }
  }

  /// Calls a tool and returns its result object.
  public func tool(_ name: String, _ arguments: JSONValue = [:]) async throws(FixtureError)
    -> JSONValue
  {
    let reply = try await rpc("tools/call", params: ["name": .string(name), "arguments": arguments])
    guard let result = reply["result"] else {
      throw .requestFailed
    }
    return result
  }

}

extension JSONValue {
  /// The text of a tool result's first block.
  public var resultText: String {
    guard case .array(let content) = self["content"] else {
      return ""
    }
    return content.first?["text"]?.stringValue ?? ""
  }

  /// The first picture in a tool result (like `render_frame`'s), as PNG data.
  public var resultImage: Data? {
    guard case .array(let content) = self["content"] else {
      return nil
    }
    return content.lazy.compactMap { $0["data"]?.stringValue }.first
      .flatMap { Data(base64Encoded: $0) }
  }

  /// Whether a tool result is an error.
  public var isErrorResult: Bool {
    self["isError"] == true
  }
}
