import Foundation
import ShadesCore

// MARK: - ProjectLibrary

/// The projects in `~/Shades`, for the welcome window, and creating new ones there.
public enum ProjectLibrary {

  /// Where projects live.
  public static let folder = URL.homeDirectory.appending(
    path: "Shades",
    directoryHint: .isDirectory,
  )

  /// Every project in `folder`, most recently changed first.
  @concurrent
  public static func projects(in folder: URL = folder) async -> [LibraryEntry] {
    // why: a missing folder just means there are no projects yet.
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: folder,
      includingPropertiesForKeys: [.contentModificationDateKey],
    )) ?? []
    return urls.filter { $0.pathExtension == ProjectFile.fileExtension }.map { url in
      let project = url.appending(path: "project.json")
      // why: a project without a readable date sorts last instead of hiding.
      let modified = (try? project.resourceValues(forKeys: [.contentModificationDateKey]))?
        .contentModificationDate ?? .distantPast
      return LibraryEntry(url: url, modified: modified)
    }
    .sorted { $0.modified > $1.modified }
  }

  /// Creates an empty project named `name` in `folder` and returns its URL.
  @concurrent
  public static func create(
    named name: String,
    format: VideoFormat,
    in folder: URL = folder,
  ) async throws(DocumentError) -> URL {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(":") else {
      logger.error("project.createFailed reason=invalidName")
      throw .invalidName
    }
    let url = folder.appending(
      path: "\(trimmed).\(ProjectFile.fileExtension)",
      directoryHint: .isDirectory,
    )
    guard !FileManager.default.fileExists(atPath: url.path) else {
      logger.error("project.createFailed reason=nameTaken")
      throw .nameTaken(trimmed)
    }
    try await ProjectFile.write(
      Project(timeline: Timeline(format: format, defaultFit: .fill)),
      session: Session(),
      to: url,
    )
    return url
  }

  /// A name not used yet in `folder`: "Untitled", then "Untitled 2"…
  public static func unusedName(_ base: String = "Untitled", in folder: URL = folder) -> String {
    var name = base
    var number = 2
    while
      FileManager.default
        .fileExists(atPath: folder.appending(path: "\(name).\(ProjectFile.fileExtension)").path)
    {
      name = "\(base) \(number)"
      number += 1
    }
    return name
  }

}

// MARK: - LibraryEntry

/// One project in the library.
public struct LibraryEntry: Hashable, Sendable, Identifiable {
  public let url: URL
  public let modified: Date

  public var id: URL {
    url
  }

  /// The project's name: its file name without `.shades`.
  public var name: String {
    url.deletingPathExtension().lastPathComponent
  }
}
