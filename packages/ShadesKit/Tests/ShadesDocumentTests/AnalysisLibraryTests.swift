import Foundation
import ShadesCore
import ShadesDocument
import Testing

@MainActor
struct AnalysisLibraryTests {

  // MARK: Internal

  @Test
  func `saved analysis loads back in a fresh library`() async throws {
    let id = UUID()
    let library = AnalysisLibrary()
    let speech = [TimeRange(start: MediaTime(seconds: 1), end: MediaTime(seconds: 2))]
    try await library.update(id, in: package) { $0.speech = speech }
    try await library.update(id, in: package) { $0.beats = BeatGrid(
      beatsPerMinute: 120,
      beats: [.zero],
    ) }
    let reloaded = AnalysisLibrary()
    await reloaded.load(from: package)
    #expect(reloaded.analyses[id]?.speech == speech)
    #expect(reloaded.analyses[id]?.beats?.beatsPerMinute == 120)
  }

  @Test
  func `a project with no analysis loads empty`() async {
    let library = AnalysisLibrary()
    await library.load(from: package)
    #expect(library.analyses.isEmpty)
  }

  // MARK: Private

  private let package = FileManager.default.temporaryDirectory
    .appending(path: "\(UUID().uuidString).shades", directoryHint: .isDirectory)

}
