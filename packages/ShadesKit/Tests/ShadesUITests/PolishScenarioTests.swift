import Foundation
import ShadesCore
import ShadesDocument
import ShadesTestSupport
@testable import ShadesUI
import Testing

// MARK: - PolishScenarioTests

/// Quality gate 2: Claude's analysis and Polish tools over real HTTP, against a real workspace.
@MainActor
struct PolishScenarioTests {

  // MARK: Internal

  @Test
  func `analyse sound, propose Polish, apply it: the pauses are gone`() async throws {
    let package = FileManager.default.temporaryDirectory.appending(
      path: "\(UUID().uuidString).shades",
      directoryHint: .isDirectory,
    )
    try await ProjectFile.write(Project(), session: Session(), to: package)
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: Self.port,
    )
    defer { workspace.server.stop() }
    try await workspace.openProject(at: package)
    for _ in 0 ..< 200 where workspace.server.status == .starting {
      try await Task.sleep(for: .milliseconds(10))
    }

    let talk = try AudioFixture.makeBursts(seconds: 6, bursts: [(1, 2), (4, 5)])
    _ = try await call("import_media", ["path": .string(talk.path)])
    let mediaID = try #require(workspace.editor.project.media.first?.id.uuidString)
    _ = try await call("append_clip", ["media_id": .string(mediaID)])
    _ = try await call("analyze_audio")
    await workspace.jobs.waitUntilIdle()

    let plan = try await call("polish_propose", ["start": 0, "end": 6, "track": "A1"])
    #expect(plan.contains("Cut silences"))
    let applied = try await call("polish_apply")
    #expect(applied.contains("Polished"))
    // Three pauses (before, between, after) come out; about 2 s of speech (plus padding) stays.
    #expect(workspace.editor.project.timeline.duration.seconds < 3.2)
    _ = try await call("undo")
    #expect(workspace.editor.project.timeline.duration == MediaTime(seconds: 6))
  }

  // MARK: Private

  private static let port: UInt16 = 47_496

  /// Calls a tool over HTTP and returns its text.
  private func call(
    _ name: String,
    _ arguments: [String: JSONValueLiteral] = [:],
  ) async throws -> String {
    var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:\(Self.port)/mcp")))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
      "jsonrpc": "2.0",
      "id": 1,
      "method": "tools/call",
      "params": ["name": name, "arguments": arguments.mapValues(\.value)],
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, _) = try await URLSession.shared.data(for: request)
    let reply = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let result = try #require(reply["result"] as? [String: Any])
    let content = try #require(result["content"] as? [[String: Any]])
    return content.first?["text"] as? String ?? ""
  }

}

// MARK: - JSONValueLiteral

/// A JSON argument value, written as a literal in the test.
enum JSONValueLiteral: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
  case string(String)
  case number(Int)

  init(stringLiteral value: String) {
    self = .string(value)
  }

  init(integerLiteral value: Int) {
    self = .number(value)
  }

  var value: Any {
    switch self {
    case .string(let text): text
    case .number(let number): number
    }
  }
}
