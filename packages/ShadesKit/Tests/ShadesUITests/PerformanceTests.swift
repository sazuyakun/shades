import Foundation
import ShadesCommands
import ShadesCore
import ShadesDocument
import ShadesEngine
import ShadesMedia
import ShadesTestSupport
import ShadesUI
import Testing

/// Performance gates for the editor as a whole, on a 10-minute 4K project (see the engine's
/// `PerformanceTests` for how budgets are set and run).
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SHADES_PERFORMANCE"] == "1"))
struct PerformanceTests {

  // MARK: Internal

  @Test
  func `a 10-minute project opens in under 2 s`() async throws {
    let url = try await tenMinuteProject()
    let time = try await Benchmark.median(runs: 3) {
      let workspace = Self.workspace()
      try await workspace.openProject(at: url)
      try await workspace.player.load(workspace.editor.project)
      await workspace.close()
    }
    // why: PLAN §4's target; measured 0.6 s on the M1 dev machine.
    #expect(time < .seconds(2), "took \(time)")
  }

  @Test
  func `an edit reaches the timeline and the preview within a frame`() async throws {
    let workspace = try await openTenMinuteProject()
    let editor = workspace.editor
    let clips = editor.project.timeline.tracks[0].clips
    let frame = Duration.seconds(1.0 / 24)
    var opacity = 1.0
    let look = try await Benchmark.median {
      opacity = opacity == 1 ? 0.8 : 1
      try editor.perform(SetClip(clipID: clips[30].id, opacity: opacity))
      try await workspace.player.load(editor.project)
    }
    // why: PLAN §4: within a frame at 24 fps. Measured 2–7 ms for a look change (the preview
    // updates live) and 0.2 ms for a split (the timeline; playback rebuilds after) on the M1.
    #expect(look < frame, "a look change took \(look)")
    var index = 0
    let split = try await Benchmark.median {
      let clip = clips[index]
      index += 1
      try editor.perform(SplitClip(clipID: clip.id, at: clip.timelineStart + MediaTime(seconds: 5)))
    }
    #expect(split < frame, "a split took \(split)")
    await workspace.close()
  }

  @Test
  func `an open project sits idle at near 0% CPU and under 1.5 GB`() async throws {
    let workspace = try await openTenMinuteProject()
    let context = try workspace.player.renderContext()
    for seconds in [12.0, 300, 590] {
      _ = try await FrameRenderer.png(
        of: workspace.editor.project,
        atSeconds: seconds,
        maxSide: 2880,
        context: context,
      )
    }
    try await Task.sleep(for: .seconds(1)) // why: lets the open settle before measuring.
    let meter = CPUMeter()
    try await Task.sleep(for: .seconds(3))
    let usage = meter.usage()
    // why: PLAN §4 asks for ~0%; measured 0.05% here and 0.2–0.4% in the app on the M1.
    #expect(usage < 3, "used \(usage)% of a core")
    #expect(Benchmark.memoryFootprint() < 1_500_000_000)
    await workspace.close()
  }

  // MARK: Private

  private static func workspace() -> Workspace {
    Workspace(
      defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard,
      port: 0,
      pauseCheck: { _ in nil },
    )
  }

  /// The 10-minute project, open, with playback loaded.
  private func openTenMinuteProject() async throws -> Workspace {
    let workspace = Self.workspace()
    try await workspace.openProject(at: tenMinuteProject())
    try await workspace.player.load(workspace.editor.project)
    return workspace
  }

  /// Writes a 10-minute 4K project like a real edit: 60 ten-second clips from six 4K files on
  /// V1 (with their 1080p proxies made already, as after the first open), B-roll on V2 and a
  /// caption every three seconds.
  private func tenMinuteProject() async throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "\(UUID().uuidString).shades", directoryHint: .isDirectory)
    var media = [Media]()
    for shade in 0 ..< 6 {
      let gray = FixtureColor(red: UInt8(40 * shade), green: 100, blue: 160)
      let file = try await VideoFixture.make(
        left: gray,
        right: gray,
        seconds: 10,
        width: 1920,
        height: 1080,
        codec: .hevc,
      )
      let item = Media(
        url: file,
        duration: MediaTime(seconds: 10),
        width: 3840,
        height: 2160,
        hasAudio: false,
      )
      let proxy = ProxyMaker.proxyURL(for: item, in: url.appending(path: "cache"))
      try FileManager.default.createDirectory(
        at: proxy.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      try FileManager.default.copyItem(at: file, to: proxy)
      media.append(item)
    }
    let clip = { (index: Int, track: Int) in
      Clip(
        mediaID: media[(index + track) % media.count].id,
        sourceStart: .zero,
        duration: MediaTime(seconds: 10),
        timelineStart: MediaTime(seconds: Double(index * 10)),
        transform: track == 0 ? .identity : ClipTransform(scale: 0.4),
      )
    }
    let captions = (0 ..< 200).map { index in
      Clip(
        source: .text(TextContent(text: "Caption \(index)")),
        sourceStart: .zero,
        duration: MediaTime(seconds: 2),
        timelineStart: MediaTime(seconds: Double(index * 3)),
      )
    }
    let project = Project(media: media, timeline: Timeline(format: .standard, tracks: [
      Track(kind: .video, clips: (0 ..< 60).map { clip($0, 0) }),
      Track(kind: .video, clips: stride(from: 0, to: 60, by: 3).map { clip($0, 1) }),
      Track(kind: .text, clips: captions),
    ]))
    try await ProjectFile.write(project, session: Session(), to: url)
    return url
  }

}
