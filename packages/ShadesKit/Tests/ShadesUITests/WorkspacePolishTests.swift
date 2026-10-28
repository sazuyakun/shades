import Foundation
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesPolish
import ShadesTestSupport
@testable import ShadesUI
import Testing

@MainActor
struct WorkspacePolishTests {
  @Test
  func `a plan is discarded when the timeline changes under it, and applying clears it`(
  ) async throws {
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
    _ = try await workspace.applyPolish(ids: nil, kinds: [.silence])
    #expect(workspace.polishPlan == nil)
  }

  @Test
  func `with sound to clean, the loudness is set after the cleaning, on the cleaned mix`(
  ) async throws {
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
      pauseCheck: { _ in nil },
    )
    let media = try Media(
      url: AudioFixture.makeTone(seconds: 2, amplitude: 0.3),
      duration: MediaTime(seconds: 2),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    let package = FileManager.default.temporaryDirectory
      .appending(path: "\(UUID().uuidString).shades")
    try await ProjectFile.write(Project(media: [media]), session: Session(), to: package)
    try await workspace.openProject(at: package)
    try workspace.editor.perform(AppendClip(mediaID: media.id))
    try await workspace.analysis.update(media.id, in: package) { $0.noiseFloor = -30 }
    let range = TimeRange(start: .zero, end: MediaTime(seconds: 2))
    workspace.proposePolish(
      in: range,
      track: "A1",
      options: PolishOptions(silences: false, fillers: false, retakes: false, duck: false),
    )
    _ = try await workspace.applyPolish(ids: nil, kinds: nil)
    #expect(workspace.editor.project.timeline.gain == 1, "not measured before the cleaning")
    let titles = workspace.jobs.jobs.map(\.title)
    let cleaning = try #require(titles.firstIndex { $0.hasPrefix("Cleaning the sound") })
    let loudness = try #require(titles.firstIndex { $0.hasPrefix("Setting the loudness") })
    #expect(cleaning < loudness)
    for _ in 0 ..< 300 where workspace.editor.project.timeline.gain == 1 {
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(workspace.editor.project.timeline.gain != 1)
    await workspace.close()
  }
}
