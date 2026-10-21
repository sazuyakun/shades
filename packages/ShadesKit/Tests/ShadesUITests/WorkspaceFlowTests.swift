import Foundation
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesTestSupport
@testable import ShadesUI
import Testing

@MainActor
struct WorkspaceFlowTests {
  @Test
  func `switching footage blur on queues one motion job for its video`() async throws {
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
    )
    let media = try await Media(
      url: VideoFixture.make(red: 10, green: 20, blue: 30, seconds: 1),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let package = FileManager.default.temporaryDirectory
      .appending(path: "\(UUID().uuidString).shades")
    try await ProjectFile.write(Project(media: [media]), session: Session(), to: package)
    try await workspace.openProject(at: package)
    try workspace.editor.perform(AppendClip(mediaID: media.id))
    workspace.projectDidChange()
    let title = "Measuring the motion in \(media.name)"
    #expect(!workspace.jobs.jobs.contains { $0.title == title })
    let clip = try #require(workspace.editor.project.timeline.allClips.first?.id)
    try workspace.editor.perform(SetClip(clipID: clip, footageBlur: true))
    workspace.projectDidChange()
    workspace.projectDidChange()
    #expect(workspace.jobs.jobs.count { $0.title == title } == 1)
    await workspace.close()
  }
}
