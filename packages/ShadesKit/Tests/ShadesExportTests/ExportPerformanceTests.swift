import Foundation
import ShadesCore
import ShadesExport
import ShadesTestSupport
import Testing

/// Export speed gate (see the engine's `PerformanceTests` for how budgets are set and run).
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SHADES_PERFORMANCE"] == "1"))
struct ExportPerformanceTests {

  @Test
  func `a youtube export runs faster than real time`() async throws {
    let teal = FixtureColor(red: 20, green: 140, blue: 150)
    let video = Media(
      url: try await VideoFixture.make(
        left: teal,
        right: teal,
        seconds: 4,
        width: 1920,
        height: 1080,
      ),
      duration: MediaTime(seconds: 4),
      width: 1920,
      height: 1080,
      hasAudio: false,
    )
    let project = Project(media: [video], timeline: Timeline(
      format: .half,
      tracks: [Track(kind: .video, clips: [Clip(
        mediaID: video.id,
        sourceStart: .zero,
        duration: video.duration,
        timelineStart: .zero,
      )])],
    ))
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
    let clock = ContinuousClock()
    let start = clock.now
    try await MovieExporter.export(project, to: url, canvas: .youtube, progress: { _ in })
    let time = clock.now - start
    // why: the timeline is 4 s long; plain cuts must export faster than they play.
    #expect(time < .seconds(4), "took \(time)")
  }

}
