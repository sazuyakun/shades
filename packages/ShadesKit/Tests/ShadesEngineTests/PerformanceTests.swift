import AVFoundation
import Foundation
import ShadesCore
import ShadesEngine
import ShadesMatting
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
  func `a frame with motion blur on a moving layer and its footage renders within budget`()
    async throws
  {
    var project = try await oneClipProject(width: 1920, height: 1080)
    let media = try #require(project.media.first)
    let flow = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await FlowMaker.make(from: media.url, to: flow) { _ in }
    project.timeline.tracks[0].clips[0].footageBlur = true
    project.timeline.tracks[0].clips[0].keyframes = [
      Keyframe(property: .x, time: .zero, value: -0.5),
      Keyframe(property: .x, time: MediaTime(seconds: 1), value: 0.5),
    ]
    let context = try RenderContext()
    let time = try await Benchmark.median {
      _ = try await FrameRenderer.png(
        of: project,
        atSeconds: 0.5,
        maxSide: 1440,
        context: context,
        flows: [media.id: flow],
      )
    }
    // why: the layer is drawn at 32 moments (full quality) and the footage smeared too.
    // Measured 0.19 s on the M1 dev machine (0.16 s without blur) and 0.55 s on the CI runner.
    #expect(time < .milliseconds(1000))
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

  @MainActor
  @Test
  func `the target timeline plays in real time without dropping frames`() async throws {
    let target = try await targetTimeline()
    let player = try await load(target)
    player.previewQuality = .half
    player.play()
    // why: playback takes a moment to start; real time is judged once it's running.
    try await Task.sleep(for: .seconds(1))
    let clock = ContinuousClock()
    let started = (clock.now, player.currentTime)
    try await Task.sleep(for: .seconds(3))
    let advanced = player.currentTime - started.1
    let elapsed = clock.now - started.0
    player.pause()
    // why: PLAN §4 allows proxies and a half-size preview for this timeline. Neither the M1 dev
    // machine nor the CI runner drops a frame.
    #expect(player.frameCounter.droppedFrames == 0)
    #expect(.seconds(advanced) > elapsed * 0.95, "played \(advanced) s in \(elapsed)")
  }

  @MainActor
  @Test
  func `scrubbing shows each new frame within budget`() async throws {
    let target = try await targetTimeline()
    let player = try await load(target)
    let output = try #require(player.avPlayer.currentItem?.outputs
      .first as? AVPlayerItemVideoOutput)
    let clock = ContinuousClock()
    var waits = [Duration]()
    for target in [2.1, 0.4, 3.3, 1.2, 4.6, 0.9, 2.8, 3.9] {
      let started = clock.now
      await player.seek(toSeconds: target)
      try await waitForFrame(from: output, of: player)
      waits.append(clock.now - started)
    }
    let median = waits.sorted()[waits.count / 2]
    // why: PLAN §4's target is 50 ms on the M1, which measures 20 ms (full size). The CI
    // runner's virtual GPU and software decoding take about three times as long (65 ms).
    #expect(median < .milliseconds(150), "scrubs took \(waits)")
    // why: PLAN §4's ceiling for editing a 4K project; this one plays three layers of it.
    #expect(Benchmark.memoryFootprint() < 1_500_000_000)
  }

  // MARK: Private

  /// PLAN §4's playback target: a 2880×2160 @ 24 timeline of three graded layers of 4K footage
  /// (played from 1080p proxies, as Shades does) and text behind the subject, with the proxies
  /// and the base layer's cut-out to load it with.
  private func targetTimeline() async throws -> (Project, [Media.ID: URL], [Media.ID: URL]) {
    var media = [Media]()
    var proxies = [Media.ID: URL]()
    for (red, green, blue) in [(200, 120, 80), (60, 140, 200), (90, 200, 110)] {
      let color = FixtureColor(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
      let proxy = try await VideoFixture.make(
        left: color,
        right: color,
        seconds: 5,
        width: 1920,
        height: 1080,
        codec: .hevc,
      )
      let original = Media(
        url: proxy,
        duration: MediaTime(seconds: 5),
        width: 3840,
        height: 2160,
        hasAudio: false,
      )
      media.append(original)
      proxies[original.id] = proxy
    }
    let matte = try await VideoFixture.make(
      red: 255,
      green: 255,
      blue: 255,
      seconds: 5,
      width: 640,
      height: 360,
    )
    let tracks = media.enumerated().map { index, media in
      Track(kind: .video, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.duration,
        timelineStart: .zero,
        transform: index == 0 ? .identity : ClipTransform(scale: 0.5),
        grade: Grade(exposure: 0.2, contrast: 1.1, saturation: 1.2),
      )])
    }
    var title = Clip(
      source: .text(TextContent(text: "BEHIND THE SUBJECT")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 5),
      timelineStart: .zero,
    )
    title.depth = .behindSubject
    let project = Project(media: media, timeline: Timeline(
      format: .standard,
      tracks: tracks + [Track(kind: .text, clips: [title])],
    ))
    return (project, proxies, [media[0].id: matte])
  }

  /// A player with `target` loaded, paused at the start, its frames going to a video output as
  /// they would to the viewer.
  @MainActor
  private func load(_ target: (Project, [Media.ID: URL], [Media.ID: URL])) async throws
    -> Player
  {
    let player = Player()
    player.proxies = target.1
    player.mattes = target.2
    try await player.load(target.0)
    let item = try #require(player.avPlayer.currentItem)
    item.add(AVPlayerItemVideoOutput(pixelBufferAttributes: nil))
    return player
  }

  /// Waits until `output` has the frame at the player's time, for at most a second.
  @MainActor
  private func waitForFrame(from output: AVPlayerItemVideoOutput, of player: Player) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      let time = player.avPlayer.currentTime()
      if
        output.hasNewPixelBuffer(forItemTime: time),
        output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) != nil
      {
        return
      }
      try await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("no frame came within a second")
  }

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
