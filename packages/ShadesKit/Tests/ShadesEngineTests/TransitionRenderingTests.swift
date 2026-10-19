import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Transitions between two clips, drawn across the cut.
struct TransitionRenderingTests {

  // MARK: Internal

  @Test
  func `transition styles fade, dip, move and wipe as they run`() {
    #expect(TransitionStyle(kind: .dissolve, progress: 0.25, isIncoming: true).opacity == 0.25)
    #expect(TransitionStyle(kind: .dipToBlack, progress: 0.5, isIncoming: true).dip == 1)
    #expect(TransitionStyle(kind: .dipToBlack, progress: 0.25, isIncoming: true).opacity == 0)
    #expect(TransitionStyle(kind: .push, progress: 1, isIncoming: false).offsetX == -1)
    #expect(TransitionStyle(kind: .iris, progress: 0.4, isIncoming: true).wipe == .iris)
    #expect(TransitionStyle(kind: .iris, progress: 0.4, isIncoming: false).wipe == nil)
  }

  @Test
  func `a dissolve mixes the two clips at the cut, using held frames past their ends`(
  ) async throws {
    let png = try await frame(.dissolve, at: 1.0)
    let middle = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    #expect((90 ... 170).contains(Int(middle.red)) && (90 ... 170).contains(Int(middle.blue)))
    let before = try await frame(.dissolve, at: 0.6)
    #expect(try PixelProbe.color(of: before, x: 0.5, y: 0.5).red > 200)
  }

  @Test
  func `an iris opens the next clip from the middle`() async throws {
    let png = try await frame(.iris, at: 1.0)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).blue > 200)
    #expect(try PixelProbe.color(of: png, x: 0.05, y: 0.1).red > 200)
    #expect(try GoldenFrame.matches(png, named: "transition-iris", in: golden))
  }

  @Test
  func `slices slide the next clip in band by band`() async throws {
    let png = try await frame(.slices, at: 1.05)
    #expect(try GoldenFrame.matches(png, named: "transition-slices", in: golden))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A 1-second red clip then a 1-second blue one, joined by an 0.8-second `kind`.
  private func frame(_ kind: TransitionKind, at seconds: Double) async throws -> Data {
    let red = try await media(FixtureColor(red: 255, green: 0, blue: 0))
    let blue = try await media(FixtureColor(red: 0, green: 0, blue: 255))
    let first = Clip(
      mediaID: red.id,
      sourceStart: .zero,
      duration: red.duration,
      timelineStart: .zero,
    )
    let second = Clip(
      mediaID: blue.id,
      sourceStart: .zero,
      duration: blue.duration,
      timelineStart: MediaTime(seconds: 1),
      transitionIn: Transition(kind: kind, duration: MediaTime(seconds: 0.8)),
    )
    let project = Project(
      media: [red, blue],
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [first, second])]),
    )
    return try await FrameRenderer.png(of: project, atSeconds: seconds, maxSide: 320)
  }

  private func media(_ color: FixtureColor) async throws -> Media {
    let url = try await VideoFixture.make(left: color, right: color, width: 320, height: 240)
    return Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 240,
      hasAudio: false,
    )
  }

}
