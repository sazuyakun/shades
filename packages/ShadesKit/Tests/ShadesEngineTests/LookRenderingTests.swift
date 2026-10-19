import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Grades, blend modes, film-look effects, keys and adjustment clips, drawn by the compositor.
struct LookRenderingTests {

  // MARK: Internal

  @Test
  func `exposure brightens and saturation 0 makes black and white`() async throws {
    let brighter = try await frame(top: nil) { $0.grade = Grade(exposure: 1) }
    #expect(try PixelProbe.color(of: brighter, x: 0.5, y: 0.5).red > 120)
    let gray = try await frame(top: nil) { $0.grade = Grade(saturation: 0) }
    let center = try PixelProbe.color(of: gray, x: 0.5, y: 0.5)
    #expect(abs(Int(center.red) - Int(center.green)) < 4 &&
      abs(Int(center.green) - Int(center.blue)) < 4)
  }

  @Test
  func `curves and a LUT reshape colour`() async throws {
    let lut = try writeLUT { red, green, blue in (1 - red, 1 - green, 1 - blue) }
    let inverted = try await frame(top: nil) { $0.grade = Grade(lut: lut.path) }
    #expect(try PixelProbe.color(of: inverted, x: 0.5, y: 0.5).blue > 200)
    let crushed = try await frame(top: nil) {
      $0.grade = Grade(curves: Curves(master: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 1, y: 0)]))
    }
    #expect(try PixelProbe.color(of: crushed, x: 0.5, y: 0.5).red < 10)
  }

  @Test
  func `screen brightens, multiply darkens, and normal covers`() async throws {
    let gray = FixtureColor(red: 128, green: 128, blue: 128)
    let screen = try await frame(top: gray) { $0.blend = .screen }
    let multiply = try await frame(top: gray) { $0.blend = .multiply }
    let normal = try await frame(top: gray) { _ in }
    let base = 100
    #expect(Int(try PixelProbe.color(of: screen, x: 0.5, y: 0.5).red) > base + 40)
    #expect(Int(try PixelProbe.color(of: multiply, x: 0.5, y: 0.5).red) < 70)
    #expect(abs(Int(try PixelProbe.color(of: normal, x: 0.5, y: 0.5).red) - 128) < 6)
  }

  @Test
  func `a green screen is keyed out to show what's under it`() async throws {
    let green = FixtureColor(red: 0, green: 255, blue: 0)
    let keyed = try await frame(top: green) { $0.effects = Effects(key: ChromaKey()) }
    #expect(try PixelProbe.color(of: keyed, x: 0.5, y: 0.5).green < 40)
  }

  @Test
  func `an adjustment clip grades everything under it, with a vignette`() async throws {
    let png = try await frame(top: nil, adjustment: Clip(
      source: .adjustment,
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      grade: Grade(saturation: 0),
      effects: Effects(vignette: 1),
    ))
    let center = try PixelProbe.color(of: png, x: 0.5, y: 0.5)
    #expect(abs(Int(center.red) - Int(center.blue)) < 4)
    let corner = try PixelProbe.color(of: png, x: 0.03, y: 0.15)
    #expect(Int(corner.red) < Int(center.red) - 15)
    #expect(try GoldenFrame.matches(png, named: "adjustment-gray-vignette", in: golden))
  }

  @Test
  func `grain is the same for the same frame`() async throws {
    let first = try await frame(top: nil) { $0.effects = Effects(grain: 1) }
    let again = try await frame(top: nil) { $0.effects = Effects(grain: 1) }
    #expect(first == again)
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// A dull red clip (100, 30, 30) on V1, optionally a `top` coloured clip on V2 (changed by
  /// `change`; otherwise `change` applies to the red one), and an adjustment clip on top.
  private func frame(
    top: FixtureColor?,
    adjustment: Clip? = nil,
    change: (inout Clip) -> Void = { _ in },
  ) async throws -> Data {
    let red = try await media(FixtureColor(red: 100, green: 30, blue: 30))
    var base = clip(of: red)
    var allMedia = [red]
    var tracks = [Track]()
    if let top {
      let topMedia = try await media(top)
      var upper = clip(of: topMedia)
      upper.transform.scale = 0.5
      change(&upper)
      allMedia.append(topMedia)
      tracks = [Track(kind: .video, clips: [base]), Track(kind: .video, clips: [upper])]
    } else {
      change(&base)
      tracks = [Track(kind: .video, clips: [base])]
    }
    if let adjustment {
      tracks.append(Track(kind: .video, clips: [adjustment]))
    }
    let project = Project(media: allMedia, timeline: Timeline(format: .half, tracks: tracks))
    return try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
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

  private func clip(of media: Media) -> Clip {
    Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero)
  }

  /// A 17-point `.cube` file mapping each colour through `map`.
  private func writeLUT(_ map: (Double, Double, Double) -> (Double, Double, Double)) throws -> URL {
    var lines = ["LUT_3D_SIZE 17"]
    for blue in 0 ..< 17 {
      for green in 0 ..< 17 {
        for red in 0 ..< 17 {
          let out = map(Double(red) / 16, Double(green) / 16, Double(blue) / 16)
          lines.append("\(out.0) \(out.1) \(out.2)")
        }
      }
    }
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).cube")
    try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    return url
  }

}
