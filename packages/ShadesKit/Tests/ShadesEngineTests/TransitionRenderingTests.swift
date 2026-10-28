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
    let whipOut = TransitionStyle(kind: .whip, progress: 0.4, isIncoming: false)
    let whipIn = TransitionStyle(kind: .whip, progress: 0.4, isIncoming: true)
    #expect(abs(whipIn.offsetX - whipOut.offsetX - 1) < 0.0001, "the shots stay joined")
    #expect(whipIn.opacity == 1 && whipOut.opacity == 1 && whipIn.blur > 0.5)
    #expect(TransitionStyle(kind: .iris, progress: 0.4, isIncoming: true).wipe == .iris)
    #expect(TransitionStyle(kind: .iris, progress: 0.4, isIncoming: false).wipe == nil)
  }

  @Test
  func `flash frames hold a solid colour or the negative, then cut`() {
    let white = TransitionStyle(kind: .flashWhite, progress: 0.25, isIncoming: false)
    #expect(white.dip == 1 && white.dipsToWhite && white.opacity == 1)
    let black = TransitionStyle(kind: .flashBlack, progress: 0.75, isIncoming: true)
    #expect(black.dip == 1 && !black.dipsToWhite && black.opacity == 1)
    let inverted = TransitionStyle(kind: .flashInvert, progress: 0.25, isIncoming: false)
    #expect(inverted.invert == 1 && inverted.dip == 0)
    #expect(TransitionStyle(kind: .flashInvert, progress: 0.25, isIncoming: true).opacity == 0)
  }

  @Test
  func `an inverted flash shows each shot's negative on its side of the cut`() async throws {
    let before = try await frame(.flashInvert, at: 0.7)
    let outgoing = try PixelProbe.color(of: before, x: 0.5, y: 0.5)
    #expect(outgoing.red < 60 && outgoing.green > 200 && outgoing.blue > 200, "red's negative")
    let after = try await frame(.flashInvert, at: 1.2)
    let incoming = try PixelProbe.color(of: after, x: 0.5, y: 0.5)
    #expect(incoming.red > 200 && incoming.green > 200 && incoming.blue < 60, "blue's negative")
    let past = try await frame(.flashInvert, at: 1.5)
    #expect(try PixelProbe.color(of: past, x: 0.5, y: 0.5).blue > 200, "cut back to normal")
  }

  @Test
  func `white and black flash frames cover the picture`() async throws {
    let whiteFrame = try await frame(.flashWhite, at: 0.7)
    let white = try PixelProbe.color(of: whiteFrame, x: 0.5, y: 0.5)
    #expect(white.red > 240 && white.green > 240 && white.blue > 240)
    let blackFrame = try await frame(.flashBlack, at: 1.2)
    let black = try PixelProbe.color(of: blackFrame, x: 0.5, y: 0.5)
    #expect(black.red < 15 && black.green < 15 && black.blue < 15)
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
  }

  @Test(arguments: TransitionKind.allCases)
  func `every transition at mid-progress matches its golden frame`(
    kind: TransitionKind
  ) async throws {
    let png = try await frame(kind, at: 1.0)
    #expect(try GoldenFrame.matches(
      png,
      named: "transition-\(kind.rawValue.lowercased())",
      in: golden,
    ))
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
