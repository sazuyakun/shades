import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct CommandRegistryTests {
  @Test
  func `tool names are unique`() {
    let names = CommandRegistry.tools.map { $0.name }
    #expect(Set(names).count == names.count)
  }

  @Test
  func `arguments decode from Claude's snake_case JSON with times in seconds`() throws {
    let clipID = UUID()
    let arguments: JSONValue = [
      "clip_id": .string(clipID.uuidString),
      "start": .number(1.5),
      "ripple": true,
    ]
    let command = try CommandRegistry.command(named: "trim_clip", arguments: arguments)
    let trim = try #require(command as? TrimClip)
    #expect(trim.clipID == clipID)
    #expect(trim.start == MediaTime(seconds: 1.5))
    #expect(trim.ripple == true)
  }

  @Test
  func `lists of IDs decode`() throws {
    let id = UUID()
    let command = try CommandRegistry.command(
      named: "delete_clips",
      arguments: ["clip_ids": [.string(id.uuidString)]],
    )
    #expect((command as? DeleteClips)?.clipIDs == [id])
  }

  @Test
  func `a missing argument is named in snake_case`() {
    #expect(throws: CommandError.invalidArguments("missing clip_id")) {
      try CommandRegistry.command(named: "split_clip", arguments: ["at": 1])
    }
  }

  @Test
  func `an unknown tool is rejected`() {
    #expect(throws: CommandError.unknownTool("fly")) {
      try CommandRegistry.command(named: "fly", arguments: [:])
    }
  }

  @Test
  func `every schema field is spelled in snake_case`() {
    for tool in CommandRegistry.tools {
      let properties = tool.parameters["properties"]
      guard case .object(let fields) = properties else {
        Issue.record("\(tool.name) has no properties")
        continue
      }
      for field in fields.keys {
        #expect(field == field.lowercased(), "\(tool.name).\(field) must be snake_case")
      }
    }
  }
}
