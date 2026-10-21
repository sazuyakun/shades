import AVFoundation
import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Speed changes, ramps and freeze frames land on the source frames `Clip.sourceTime` names, in
/// rendered frames and in the player's composition alike.
@MainActor
struct SpeedRenderingTests {

  // MARK: Internal

  @Test
  func `a ramped clip shows the source frames its speed adds up to`() async throws {
    let project = try await project(with: ramped)
    let clip = try #require(project.timeline.allClips.first)
    let moments = checkable(clip, every: 2)
    #expect(moments.count >= 6)
    for (time, frame) in moments {
      let png = try await FrameRenderer.png(of: project, atSeconds: time, maxSide: 320)
      #expect(try VideoFixture.countedFrame(in: png) == frame, "at \(time) s")
    }
  }

  @Test
  func `the player plays a ramp on the same frames as a rendered frame`() async throws {
    let project = try await project(with: ramped)
    let clip = try #require(project.timeline.allClips.first)
    let player = Player()
    try await player.load(project)
    let item = try #require(player.avPlayer.currentItem)
    let moments = checkable(clip, every: 3)
    #expect(moments.count >= 4)
    for (time, frame) in moments {
      let png = try await image(of: item, at: time)
      #expect(try VideoFixture.countedFrame(in: png) == frame, "at \(time) s")
    }
  }

  @Test
  func `twice the speed skips every other frame`() async throws {
    let project = try await project(with: Clip(
      mediaID: mediaID,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      speed: 2,
    ))
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    #expect(try VideoFixture.countedFrame(in: png) == 30)
  }

  @Test
  func `a freeze frame holds its frame from start to end`() async throws {
    let project = try await project(with: Clip(
      mediaID: mediaID,
      sourceStart: MediaTime(value: 12, timescale: 30),
      duration: MediaTime(seconds: 1.5),
      timelineStart: .zero,
      speed: 0,
    ))
    for time in [0.0, 0.7, 1.45] {
      let png = try await FrameRenderer.png(of: project, atSeconds: time, maxSide: 320)
      #expect(try VideoFixture.countedFrame(in: png) == 12)
    }
  }

  // MARK: Private

  private let mediaID = UUID()

  /// Eases from half speed up to 2× over the first second of source, then holds 2×.
  private var ramped: Clip {
    Clip(
      mediaID: mediaID,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1.3),
      timelineStart: .zero,
      keyframes: [
        Keyframe(property: .speed, time: .zero, value: 0.5, easing: .easeInOut),
        Keyframe(property: .speed, time: MediaTime(seconds: 1), value: 2),
      ],
    )
  }

  /// Every `step`th timeline frame (at 30 fps) of the clip whose source moment sits clearly
  /// inside one source frame, with that frame.
  private func checkable(_ clip: Clip, every step: Int) -> [(time: Double, frame: Int)] {
    stride(from: 0, to: Int(clip.duration.seconds * 30), by: step).compactMap { index in
      let time = Double(index) / 30
      let source = clip.sourceTime(at: MediaTime(seconds: time)).seconds
      return VideoFixture.countedFrame(atSource: source).map { (time, $0) }
    }
  }

  /// Two seconds of counted frames under `clip`, on a 30 fps 320×240 timeline.
  private func project(with clip: Clip) async throws -> Project {
    let media = Media(
      id: mediaID,
      url: try await VideoFixture.makeCounting(),
      duration: MediaTime(seconds: 2),
      width: 320,
      height: 240,
      hasAudio: false,
    )
    return Project(media: [media], timeline: Timeline(
      format: VideoFormat(width: 320, height: 240, framesPerSecond: 30),
      tracks: [Track(kind: .video, clips: [clip])],
    ))
  }

  /// The player item's frame at `seconds`, drawn through its own composition.
  private func image(of item: AVPlayerItem, at seconds: Double) async throws -> Data {
    let generator = AVAssetImageGenerator(asset: item.asset)
    generator.videoComposition = item.videoComposition
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let (image, _) = try await generator.image(at: CMTime(
      seconds: seconds,
      preferredTimescale: 600,
    ))
    return try FrameRenderer.pngData(from: image)
  }

}
