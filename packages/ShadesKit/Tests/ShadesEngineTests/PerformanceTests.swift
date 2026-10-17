import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Performance gates: budgets that fail CI on a regression. Budgets are set for the slowest
/// machine we run on (the free CI runner), well above what the M1 dev machine measures.
@Suite(.serialized)
struct PerformanceTests {

  // MARK: Internal

  @Test
  func `a timeline frame renders within budget`() async throws {
    let project = try await oneClipProject(width: 1920, height: 1080)
    let time = try await Benchmark.median {
      _ = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 1440)
    }
    // why: measured 0.13 s on the M1 dev machine and 0.27 s on the CI runner.
    #expect(time < .milliseconds(500))
  }

  @Test
  func `rendering many frames doesn't leak memory`() async throws {
    let project = try await oneClipProject(width: 320, height: 180)
    _ = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let before = Benchmark.memoryFootprint()
    for index in 0 ..< 30 {
      _ = try await FrameRenderer.png(of: project, atSeconds: Double(index) / 30, maxSide: 320)
    }
    #expect(Benchmark.memoryFootprint() - before < 40_000_000)
  }

  // MARK: Private

  private func oneClipProject(width: Int, height: Int) async throws -> Project {
    let url = try await VideoFixture.make(
      red: 40,
      green: 90,
      blue: 200,
      width: width,
      height: height,
    )
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: width,
      height: height,
      hasAudio: false,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    var project = Project(media: [media])
    project.timeline.tracks[0].clips = [clip]
    return project
  }

}
