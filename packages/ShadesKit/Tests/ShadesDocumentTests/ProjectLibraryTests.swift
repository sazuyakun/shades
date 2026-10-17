import Foundation
import ShadesCore
import ShadesDocument
import Testing

struct ProjectLibraryTests {

  // MARK: Internal

  @Test
  func `a new project is created in the library with its format`() async throws {
    let url = try await ProjectLibrary.create(named: "Chul", format: .half, in: folder)
    #expect(url.lastPathComponent == "Chul.shades")
    let (project, _) = try await ProjectFile.read(at: url)
    #expect(project.timeline.format == .half)
    #expect(await ProjectLibrary.projects(in: folder).map(\.name) == ["Chul"])
  }

  @Test
  func `names must be unused and valid`() async throws {
    _ = try await ProjectLibrary.create(named: "Chul", format: .standard, in: folder)
    await #expect(throws: DocumentError.nameTaken("Chul")) {
      try await ProjectLibrary.create(named: "Chul", format: .standard, in: folder)
    }
    await #expect(throws: DocumentError.invalidName) {
      try await ProjectLibrary.create(named: "a/b", format: .standard, in: folder)
    }
    #expect(ProjectLibrary.unusedName("Chul", in: folder) == "Chul 2")
  }

  @Test
  func `projects are listed most recently changed first`() async throws {
    let first = try await ProjectLibrary.create(named: "First", format: .standard, in: folder)
    _ = try await ProjectLibrary.create(named: "Second", format: .standard, in: folder)
    try await Task.sleep(for: .milliseconds(20))
    try await ProjectFile.write(Project(), session: Session(), to: first)
    #expect(await ProjectLibrary.projects(in: folder).map(\.name) == ["First", "Second"])
  }

  // MARK: Private

  private let folder = FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString, directoryHint: .isDirectory)

}
