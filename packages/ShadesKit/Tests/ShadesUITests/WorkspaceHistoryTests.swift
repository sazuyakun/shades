import Foundation
import ShadesCommands
import ShadesCore
import ShadesDocument
@testable import ShadesMCP
@testable import ShadesUI
import Testing

@MainActor
struct WorkspaceHistoryTests {

  // MARK: Internal

  @Test
  func `Claude's History is saved with the project and back when it reopens`() async throws {
    let media = Media(
      url: URL(filePath: "/tmp/a.mov"),
      duration: MediaTime(seconds: 2),
      width: 1920,
      height: 1080,
      hasAudio: false,
    )
    try await ProjectFile.write(Project(media: [media]), session: Session(), to: package)
    let workspace = Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
    )
    try await workspace.openProject(at: package)
    let activity = workspace.server.activity
    let request = activity.startRequest(named: "Rough cut").id
    let before = workspace.editor.project
    try workspace.editor.perform(AppendClip(mediaID: media.id))
    activity.record(
      "Append Clip",
      summary: "Done.",
      from: before,
      to: workspace.editor.project,
      in: request,
    )
    await workspace.close()
    try await workspace.openProject(at: package)
    #expect(activity.requests.map(\.title) == ["Rough cut"])
    try activity.undo(request, in: workspace.editor)
    #expect(workspace.editor.project.timeline.allClips.isEmpty)
    await workspace.close()
  }

  // MARK: Private

  private let package = FileManager.default.temporaryDirectory
    .appending(path: "\(UUID().uuidString).shades", directoryHint: .isDirectory)

}
