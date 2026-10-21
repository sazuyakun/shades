import AVFoundation
import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// The preview's Full, Half and Auto sizes, and the frame counter Auto and the HUD read.
@MainActor
struct PreviewQualityTests {

  // MARK: Internal

  @Test
  func `half quality plays frames at half the width and height`() async throws {
    let player = Player()
    player.previewQuality = .half
    try await player.load(project(effects: nil))
    #expect(player.isHalfSize)
    let half = try await playingFrame(of: player)
    #expect(half.width == 160 && half.height == 90)
    player.previewQuality = .full
    #expect(!player.isHalfSize)
    let full = try await playingFrame(of: player)
    #expect(full.width == 320 && full.height == 180)
  }

  @Test
  func `auto plays at full size while paused`() async throws {
    let player = Player()
    try await player.load(project(effects: nil))
    #expect(player.previewQuality == .auto)
    #expect(!player.isHalfSize)
  }

  @Test
  func `a half-size frame blurs the same part of the picture as a full one`() async throws {
    let player = Player()
    let project = try await project(effects: Effects(blur: 1))
    let full = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    player.previewQuality = .half
    try await player.load(project)
    let half = try await FrameRenderer.pngData(from: playingFrame(of: player))
    for x in [0.44, 0.47, 0.53, 0.56] {
      let fullRed = Int(try PixelProbe.color(of: full, x: x, y: 0.5).red)
      let halfRed = Int(try PixelProbe.color(of: half, x: x, y: 0.5).red)
      #expect(abs(fullRed - halfRed) < 24, "at x \(x): full \(fullRed), half \(halfRed)")
    }
  }

  @Test
  func `frames skipped while playing count as dropped, seeks don't`() {
    let counter = FrameCounter()
    counter.playbackStarted(frameDuration: 0.04)
    for time in [0, 0.04, 0.08, 0.2, 0.24] {
      counter.recordFrame(at: time, took: .milliseconds(5))
    }
    #expect(counter.droppedFrames == 2)
    counter.recordFrame(at: 3, took: .milliseconds(5))
    counter.recordFrame(at: 1, took: .milliseconds(5))
    #expect(counter.droppedFrames == 2)
    counter.playbackStopped()
    counter.recordFrame(at: 1.5, took: .milliseconds(5))
    #expect(counter.droppedFrames == 2)
  }

  @Test
  func `frame time averages the last second's frames`() {
    let counter = FrameCounter()
    counter.recordFrame(at: 0, took: .milliseconds(10))
    counter.recordFrame(at: 0.04, took: .milliseconds(30))
    #expect(counter.frameTime == .milliseconds(20))
    #expect(counter.framesPerSecond == 2)
  }

  @Test
  func `a scrub's latency runs until its frame is drawn`() throws {
    let counter = FrameCounter()
    counter.expectFrame(for: .scrub, since: .now - .milliseconds(30))
    #expect(counter.scrubLatency == nil)
    counter.recordFrame(at: 1, took: .milliseconds(5))
    let latency = try #require(counter.scrubLatency)
    #expect(latency >= .milliseconds(30) && latency < .seconds(1))
    #expect(counter.editLatency == nil)
  }

  // MARK: Private

  /// A second of red on the left and blue on the right, with `effects`.
  private func project(effects: Effects?) async throws -> Project {
    let url = try await VideoFixture.make(left: .red, right: .blue)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    return Project(media: [media], timeline: Timeline(
      format: VideoFormat(width: 320, height: 180, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [Clip(
        mediaID: media.id,
        sourceStart: .zero,
        duration: media.duration,
        timelineStart: .zero,
        effects: effects,
      )])],
    ))
  }

  /// The frame the player shows at 0.5 s, drawn at the size it plays at.
  private func playingFrame(of player: Player) async throws -> CGImage {
    let item = try #require(player.avPlayer.currentItem)
    let generator = AVAssetImageGenerator(asset: item.asset)
    generator.videoComposition = item.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let image: CGImage? = await withCheckedContinuation { continuation in
      generator.generateCGImageAsynchronously(for: CMTime(value: 1, timescale: 2)) { image, _, _ in
        continuation.resume(returning: image)
      }
    }
    withExtendedLifetime(generator) { }
    return try #require(image)
  }

}
