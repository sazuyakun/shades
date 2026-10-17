import Foundation
import Observation
import ShadesCore

/// What Shades has worked out about each media file in the open project (transcripts, speech,
/// beats), kept in the package's `cache/analysis` folder so it's never redone.
@MainActor
@Observable
public final class AnalysisLibrary {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public private(set) var analyses = [Media.ID: MediaAnalysis]()

  /// Every media file's transcript, for mapping speech onto the timeline.
  public var transcripts: [Media.ID: Transcript] {
    analyses.compactMapValues(\.transcript)
  }

  /// Loads the analyses saved in a project package, replacing what was loaded before.
  public func load(from package: URL) async {
    analyses = await Self.read(from: package)
  }

  /// Forgets everything (when the project closes).
  public func clear() {
    analyses.removeAll()
  }

  /// Changes one media file's analysis and saves it in the package.
  public func update(
    _ mediaID: Media.ID,
    in package: URL,
    change: (inout MediaAnalysis) -> Void,
  ) async throws(DocumentError) {
    var analysis = analyses[mediaID] ?? MediaAnalysis()
    change(&analysis)
    analyses[mediaID] = analysis
    try await Self.write(analysis, for: mediaID, in: package)
  }

  // MARK: Private

  private nonisolated static func folder(in package: URL) -> URL {
    package.appending(path: "cache/analysis", directoryHint: .isDirectory)
  }

  @concurrent
  private static func read(from package: URL) async -> [Media.ID: MediaAnalysis] {
    // why: no analysis folder yet just means nothing has been analysed.
    let files = (try? FileManager.default.contentsOfDirectory(
      at: folder(in: package),
      includingPropertiesForKeys: nil,
    )) ?? []
    var analyses = [Media.ID: MediaAnalysis]()
    for file in files where file.pathExtension == "json" {
      guard
        let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
        // why: an unreadable cache file is just analysis to redo, not an error to show.
        let data = try? Data(contentsOf: file),
        let analysis = try? JSONDecoder().decode(MediaAnalysis.self, from: data)
      else {
        continue
      }
      analyses[id] = analysis
    }
    return analyses
  }

  @concurrent
  private static func write(
    _ analysis: MediaAnalysis,
    for id: Media.ID,
    in package: URL,
  ) async throws(DocumentError) {
    let folder = folder(in: package)
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try JSONEncoder().encode(analysis).write(
        to: folder.appending(path: "\(id.uuidString).json"),
        options: .atomic,
      )
    } catch {
      logger.error("analysis.writeFailed path=\(folder.path, privacy: .private)")
      throw .unwritable(folder)
    }
  }

}
