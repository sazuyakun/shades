import Foundation
import ShadesCore

// MARK: - ProjectFile

/// Reads and writes a `.shades` project package:
///
///     Name.shades/
///       project.json     the project (versioned)
///       session.json     playhead and selection
///       history.json     Claude's requests, for the History pane
///       thumbnail.png    a frame, for the welcome window
///       snapshots/       earlier versions, one JSON file each
///       cache/           proxies and analysis (safe to delete)
///
/// All file work runs off the main actor.
public enum ProjectFile {

  // MARK: Public

  /// The package file extension.
  public static let fileExtension = "shades"

  /// Reads a project and where the user was in it.
  @concurrent
  public static func read(at url: URL) async throws(DocumentError) -> (Project, Session) {
    let projectURL = url.appending(path: "project.json")
    guard let data = try? Data(contentsOf: projectURL) else {
      // why: a missing or unreadable file is reported as one plain-words error below.
      logger.error("project.readFailed reason=unreadable path=\(url.path, privacy: .private)")
      throw .unreadable(url)
    }
    let project = try decodeProject(data, from: url)
    // why: a missing or damaged session only loses the playhead, so it falls back to defaults.
    let session = (try? Data(contentsOf: url.appending(path: "session.json")))
      .flatMap { try? JSONDecoder().decode(Session.self, from: $0) } ?? Session()
    return (project, session)
  }

  /// Saves the project and session, replacing the previous files atomically.
  @concurrent
  public static func write(
    _ project: Project,
    session: Session,
    to url: URL,
  ) async throws(DocumentError) {
    try createFolders(in: url)
    try write(encode(SavedProject(project: project)), to: url.appending(path: "project.json"))
    try write(encode(session), to: url.appending(path: "session.json"))
  }

  /// Saves the frame shown in the welcome window.
  @concurrent
  public static func writeThumbnail(_ png: Data, to url: URL) async throws(DocumentError) {
    try write(png, to: url.appending(path: "thumbnail.png"))
  }

  /// Where the thumbnail is, if one was saved.
  public static func thumbnailURL(of url: URL) -> URL? {
    let thumbnail = url.appending(path: "thumbnail.png")
    return FileManager.default.fileExists(atPath: thumbnail.path) ? thumbnail : nil
  }

  /// Saves the project as a snapshot labeled `label`, and returns it.
  @concurrent
  @discardableResult
  public static func snapshot(
    _ project: Project,
    label: String,
    in url: URL,
  ) async throws(DocumentError) -> Snapshot {
    try createFolders(in: url)
    let date = Date.now
    let stamp = Int(date.timeIntervalSince1970 * 1000)
    let name = "\(stamp)-\(label.filter { $0.isLetter || $0.isNumber || $0 == " " })"
    let file = url.appending(path: "snapshots/\(name).json")
    try write(encode(SavedProject(project: project, label: label)), to: file)
    return Snapshot(url: file, date: date, label: label)
  }

  /// Saves Claude's History (its owner decides the shape) next to the project.
  @concurrent
  public static func writeHistory(
    _ history: some Encodable & Sendable,
    to url: URL,
  ) async throws(DocumentError) {
    try write(encode(history), to: url.appending(path: "history.json"))
  }

  /// Reads Claude's History, or `nil` when there's none or it can't be read.
  @concurrent
  public static func readHistory<History: Decodable & Sendable>(
    _: History.Type,
    at url: URL,
  ) async -> History? {
    // why: no file means Claude hasn't changed this project yet.
    guard let data = try? Data(contentsOf: url.appending(path: "history.json")) else {
      return nil
    }
    do {
      return try JSONDecoder().decode(History.self, from: data)
    } catch {
      // why: a damaged History only loses the log; the project opens without it.
      logger.error("history.readFailed reason=damaged path=\(url.path, privacy: .private)")
      return nil
    }
  }

  /// Every snapshot, newest first.
  @concurrent
  public static func snapshots(in url: URL) async -> [Snapshot] {
    let folder = url.appending(path: "snapshots")
    // why: no snapshots folder yet just means there are no snapshots.
    let files = (try? FileManager.default.contentsOfDirectory(
      at: folder,
      includingPropertiesForKeys: nil,
    )) ?? []
    return files.filter { $0.pathExtension == "json" }.compactMap { file in
      let parts = file.deletingPathExtension().lastPathComponent.split(separator: "-", maxSplits: 1)
      guard let stamp = parts.first.flatMap({ Double($0) }) else {
        return nil
      }
      let label = parts.count > 1 ? String(parts[1]) : "Auto"
      return Snapshot(url: file, date: Date(timeIntervalSince1970: stamp / 1000), label: label)
    }
    .sorted { $0.date > $1.date }
  }

  /// Reads the project saved in a snapshot.
  @concurrent
  public static func read(_ snapshot: Snapshot) async throws(DocumentError) -> Project {
    guard let data = try? Data(contentsOf: snapshot.url) else {
      // why: reported as one plain-words error below.
      logger.error("snapshot.readFailed path=\(snapshot.url.path, privacy: .private)")
      throw .unreadable(snapshot.url)
    }
    return try decodeProject(data, from: snapshot.url)
  }

  // MARK: Private

  private static func decodeProject(_ data: Data, from url: URL) throws(DocumentError) -> Project {
    do {
      return try JSONDecoder().decode(SavedProject.self, from: data).project
    } catch {
      logger.error("project.readFailed reason=damaged path=\(url.path, privacy: .private)")
      throw .damaged(url)
    }
  }

  private static func encode(_ value: some Encodable) throws(DocumentError) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    do {
      return try encoder.encode(value)
    } catch {
      logger.fault("project.encodeFailed")
      assertionFailure("A project failed to encode")
      throw .unwritable(URL(filePath: "/"))
    }
  }

  private static func createFolders(in url: URL) throws(DocumentError) {
    do {
      for folder in ["snapshots", "cache"] {
        try FileManager.default.createDirectory(
          at: url.appending(path: folder),
          withIntermediateDirectories: true,
        )
      }
    } catch {
      logger.error("project.writeFailed reason=folder path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

  private static func write(_ data: Data, to url: URL) throws(DocumentError) {
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      logger.error("project.writeFailed path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

}

// MARK: - SavedProject

/// The JSON written to disk: a format version, so later versions of Shades can read old files.
private struct SavedProject: Codable {
  init(project: Project, label: String? = nil) {
    self.project = project
    self.label = label
  }

  static let currentVersion = 1

  var version = currentVersion
  let project: Project
  let label: String?
}
