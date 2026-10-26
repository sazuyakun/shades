import Foundation
import ShadesCore
@testable import ShadesEngine
import ShadesTestSupport
import Testing

/// Endless zooms: the picture nested inside itself, and the portal transition into the next shot.
struct PortalRenderingTests {

  // MARK: Internal

  @Test
  func `an endless zoom nests the picture inside itself`() async throws {
    let plain = try await squareScene(portal: nil)
    #expect(try PixelProbe.color(of: plain, x: 0.6, y: 0.5).blue > 200, "inside the square")
    let nested = try await squareScene(portal: Portal(nesting: 3))
    #expect(try PixelProbe.color(of: nested, x: 0.7, y: 0.5).blue > 200, "the square's rim stays")
    #expect(
      try PixelProbe.color(of: nested, x: 0.6, y: 0.5).red > 200,
      "inside it, the whole picture again, a third the size",
    )
    #expect(try PixelProbe.color(of: nested, x: 0.95, y: 0.5).red > 200, "the frame stays put")
  }

  @Test
  func `keyframed travel zooms in through the nested pictures`() async throws {
    let png = try await squareScene(portal: Portal(nesting: 3)) { clip in
      clip.keyframes = [
        Keyframe(property: .portal, time: .zero, value: 0),
        Keyframe(property: .portal, time: MediaTime(seconds: 1), value: 1),
      ]
    }
    #expect(try GoldenFrame.matches(png, named: "portal-nested-travelling", in: golden))
  }

  @Test
  func `a fast endless zoom blurs as it flies in`() async throws {
    let url = try ImageFixture.makeDisc()
    let disc = Media(
      url: url,
      duration: Media.stillLength,
      width: 400,
      height: 300,
      hasAudio: false,
      isStill: true,
    )
    let still = { (travel: Double) in
      Clip(
        mediaID: disc.id,
        sourceStart: .zero,
        duration: MediaTime(seconds: 1),
        timelineStart: .zero,
        keyframes: [
          Keyframe(property: .portal, time: .zero, value: 0),
          Keyframe(property: .portal, time: MediaTime(seconds: 1), value: travel),
        ],
        effects: Effects(portal: Portal(nesting: 3)),
      )
    }
    let render = { (travel: Double) async throws -> Data in
      let project = Project(media: [disc], timeline: Timeline(format: .half, tracks: [
        Track(kind: .video, clips: [still(travel)])
      ]))
      return try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    }
    let slow = try await render(0.02)
    let fast = try await render(6)
    /// Pixels part way between the disc's orange and the black around it, along the middle row.
    let soft = { (png: Data) throws -> Int in
      try stride(from: 0.0, through: 1, by: 0.005).count { x in
        let red = try PixelProbe.color(of: png, x: x, y: 0.5).red
        return red > 40 && red < 200
      }
    }
    #expect(try soft(fast) > soft(slow) + 5, "the rings' edges smear as it flies in")
    #expect(try GoldenFrame.matches(fast, named: "portal-zooming-blurred", in: golden))
  }

  @Test
  func `a portal transition grows the next shot's frame as fast as the last shot`() {
    let outgoing = TransitionStyle(kind: .portal, progress: 0.4, isIncoming: false)
    let incoming = TransitionStyle(kind: .portal, progress: 0.4, isIncoming: true)
    #expect(abs(outgoing.scale / incoming.scale - 6) < 0.0001, "the frame keeps its place")
    #expect(TransitionStyle(kind: .portal, progress: 0, isIncoming: false).scale == 1)
    #expect(TransitionStyle(kind: .portal, progress: 1, isIncoming: true).scale == 1)
    #expect(TransitionStyle(kind: .portal, progress: 0, isIncoming: true).opacity == 0)
  }

  @Test
  func `a portal transition flies into the next shot through its frame`() async throws {
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
      transitionIn: Transition(kind: .portal, duration: MediaTime(seconds: 0.8)),
    )
    let project = Project(
      media: [red, blue],
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [first, second])]),
    )
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.9, maxSide: 320)
    #expect(try PixelProbe.color(of: png, x: 0.5, y: 0.5).blue > 200, "the next shot's frame")
    #expect(try PixelProbe.color(of: png, x: 0.05, y: 0.5).red > 200, "the last shot round it")
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A blue square (half the frame) on red, under an adjustment clip with `portal`,
  /// rendered half a second in.
  private func squareScene(
    portal: Portal?,
    change: (inout Clip) -> Void = { _ in },
  ) async throws -> Data {
    let red = try await media(FixtureColor(red: 255, green: 0, blue: 0))
    let blue = try await media(FixtureColor(red: 0, green: 0, blue: 255))
    var square = Clip(
      mediaID: blue.id,
      sourceStart: .zero,
      duration: blue.duration,
      timelineStart: .zero,
    )
    square.transform.scale = 0.5
    var adjustment = Clip(
      source: .adjustment,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      effects: portal.map { Effects(portal: $0) },
    )
    change(&adjustment)
    let project = Project(media: [red, blue], timeline: Timeline(format: .half, tracks: [
      Track(kind: .video, clips: [Clip(
        mediaID: red.id,
        sourceStart: .zero,
        duration: red.duration,
        timelineStart: .zero,
      )]),
      Track(kind: .video, clips: [square]),
      Track(kind: .video, clips: [adjustment]),
    ]))
    return try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
  }

  /// A 1-second 4:3 clip of one colour.
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
