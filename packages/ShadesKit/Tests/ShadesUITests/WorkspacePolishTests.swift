import Foundation
import ShadesCommands
import ShadesCore
import ShadesPolish
@testable import ShadesUI
import Testing

@MainActor
struct WorkspacePolishTests {
  @Test
  func `a plan is discarded when the timeline changes under it, and applying clears it`() throws {
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
      pauseCheck: { _ in nil },
    )
    let media = Media(
      url: URL(filePath: "/tmp/a.mov"),
      duration: MediaTime(seconds: 4),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    workspace.editor.load(Project(media: [media]))
    try workspace.editor.perform(AppendClip(mediaID: media.id))
    let range = TimeRange(start: .zero, end: MediaTime(seconds: 4))
    workspace.proposePolish(in: range, track: "V1", options: PolishOptions())
    #expect(workspace.polishPlan != nil)
    try workspace.editor.perform(AddMarker(at: MediaTime(seconds: 1)))
    workspace.projectDidChange()
    #expect(workspace.polishPlan == nil)
    workspace.proposePolish(in: range, track: "V1", options: PolishOptions())
    _ = try workspace.applyPolish(ids: nil, kinds: nil)
    #expect(workspace.polishPlan == nil)
  }
}
