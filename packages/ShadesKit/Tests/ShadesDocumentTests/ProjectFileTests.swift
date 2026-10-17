import Foundation
import ShadesCore
import ShadesDocument
import Testing

struct ProjectFileTests {

  // MARK: Internal

  @Test
  func `a saved project reads back the same, with its session`() async throws {
    let media = Media(
      url: URL(filePath: "/tmp/a.mov"),
      duration: MediaTime(seconds: 3),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    var project = Project(media: [media])
    project.timeline.tracks[0].clips = [clip]
    project.timeline.markers = [Marker(time: MediaTime(seconds: 1), name: "hook")]
    let session = Session(playhead: 1.5, selection: [clip.id])
    try await ProjectFile.write(project, session: session, to: package)
    let (read, readSession) = try await ProjectFile.read(at: package)
    #expect(read == project)
    #expect(readSession == session)
  }

  @Test
  func `a missing project reports it couldn't be opened`() async {
    await #expect(throws: DocumentError.unreadable(package)) {
      try await ProjectFile.read(at: package)
    }
  }

  @Test
  func `a damaged project file is reported as damaged`() async throws {
    try await ProjectFile.write(Project(), session: Session(), to: package)
    try Data("{ nope".utf8).write(to: package.appending(path: "project.json"))
    await #expect(throws: DocumentError.damaged(package)) {
      try await ProjectFile.read(at: package)
    }
  }

  @Test
  func `snapshots list newest first with their labels and read back`() async throws {
    var older = Project()
    older.timeline.name = "older"
    try await ProjectFile.snapshot(older, label: "Before Claude", in: package)
    try await Task.sleep(for: .milliseconds(5))
    try await ProjectFile.snapshot(Project(), label: "Rough cut", in: package)
    let snapshots = await ProjectFile.snapshots(in: package)
    #expect(snapshots.map(\.label) == ["Rough cut", "Before Claude"])
    let restored = try await ProjectFile.read(try #require(snapshots.last))
    #expect(restored.timeline.name == "older")
  }

  // MARK: Private

  private let package = FileManager.default.temporaryDirectory
    .appending(path: "\(UUID().uuidString).shades", directoryHint: .isDirectory)

}
