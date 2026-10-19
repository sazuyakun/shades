import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Performance gates: budgets that fail CI on a regression. Budgets are set for the slowest
/// machine we run on (the free CI runner), well above what the M1 dev machine measures. They
/// only run with `SHADES_PERFORMANCE=1` and alone (`--no-parallel`), because other tests running
/// at the same time would skew the timings and memory.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SHADES_PERFORMANCE"] == "1"))
struct PerformanceTests {

  // MARK: Internal

  @Test
  func `a timeline frame renders within budget`() async throws {
    let project = try await oneClipProject(width: 1920, height: 1080)
    let context = try RenderContext()
    let time = try await Benchmark.median {
      _ = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 1440, context: context)
    }
    // why: measured 0.13 s on the M1 dev machine and 0.27 s on the CI runner.
    #expect(time < .milliseconds(500))
  }

  @Test
  func `rendering many frames doesn't leak memory`() async throws {
    let project = try await oneClipProject(width: 320, height: 180)
    let context = try RenderContext()
    let renderSecond = {
      for index in 0 ..< 30 {
        _ = try await FrameRenderer.png(
          of: project,
          atSeconds: Double(index) / 30,
          maxSide: 320,
          context: context,
        )
      }
    }
    // why: the CI runner's virtual GPU grows its pools in jumps now and then; a leak grows in
    // every second rendered, so the smallest growth between seconds is the one that counts.
    var footprints = [Int]()
    for _ in 0 ..< 5 {
      try await renderSecond()
      footprints.append(Benchmark.memoryFootprint())
    }
    let growth = zip(footprints, footprints.dropFirst()).map { $1 - $0 }
    #expect((growth.min() ?? 0) < 40_000_000)
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
