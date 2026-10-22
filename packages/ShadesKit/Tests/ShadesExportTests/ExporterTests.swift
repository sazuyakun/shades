import Foundation
import ShadesCore
import ShadesExport
import Testing

@MainActor
struct ExporterTests {

  @Test
  func `exporting into a folder that isn't there yet makes the folder`() async throws {
    let caption = Clip(
      source: .text(TextContent(
        text: "hello",
        words: [TimedWord(text: "hello", start: .zero, end: MediaTime(seconds: 0.5))],
      )),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    let project = Project(timeline: Timeline(tracks: [Track(kind: .text, clips: [caption])]))
    let folder = FileManager.default.temporaryDirectory
      .appending(path: "\(UUID().uuidString)/captions")
    let request = ExportRequest(kind: .srt, folder: folder, name: "talk")
    let output = try #require(request.outputs(for: project.timeline).first)
    try await Exporter.write(
      output,
      of: request,
      project: project,
      mattes: [:],
      flows: [:],
      cleanSound: [:],
      stereoSound: [:],
      transcripts: [:],
    ) { _ in }
    #expect(FileManager.default.fileExists(atPath: folder.appending(path: "talk.srt").path))
  }

}
