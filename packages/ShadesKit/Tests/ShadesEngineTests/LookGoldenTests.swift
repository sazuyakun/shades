import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Every grade, effect, key and blend mode drawn over a test chart (colour bars over a grey
/// ramp) and compared with its golden frame.
struct LookGoldenTests {

  // MARK: Internal

  @Test
  func `primaries brighten, warm and mute the chart`() async throws {
    let png = try await chart {
      $0.grade = Grade(exposure: 0.5, contrast: 1.3, saturation: 0.6, temperature: 0.5)
    }
    #expect(try GoldenFrame.matches(png, named: "grade-primaries", in: golden))
  }

  @Test
  func `lift, gamma and gain reshape the ramp`() async throws {
    let png = try await chart { $0.grade = Grade(lift: 0.15, gamma: 0.6, gain: 0.8) }
    #expect(try GoldenFrame.matches(png, named: "grade-lift-gamma-gain", in: golden))
  }

  @Test
  func `curves bend the master and each channel`() async throws {
    let png = try await chart {
      $0.grade = Grade(curves: Curves(
        master: [
          DrawingPoint(x: 0, y: 0),
          DrawingPoint(x: 0.3, y: 0.15),
          DrawingPoint(x: 0.7, y: 0.85),
          DrawingPoint(x: 1, y: 1),
        ],
        blue: [DrawingPoint(x: 0, y: 0.3), DrawingPoint(x: 1, y: 0.7)],
      ))
    }
    #expect(try GoldenFrame.matches(png, named: "grade-curves", in: golden))
  }

  @Test
  func `a LUT maps every colour`() async throws {
    let lut = try LUTFixture.make { red, green, blue in (green, blue, red) }
    let png = try await chart { $0.grade = Grade(lut: lut.path) }
    #expect(try GoldenFrame.matches(png, named: "grade-lut", in: golden))
  }

  @Test
  func `a qualifier greys out only the reds`() async throws {
    let png = try await chart { $0.grade = Grade(saturation: 0, qualifier: Qualifier(hue: 0)) }
    #expect(try GoldenFrame.matches(png, named: "grade-qualifier", in: golden))
  }

  @Test
  func `an inverted window darkens around a soft ellipse`() async throws {
    let window = GradeWindow(width: 0.5, height: 0.6, softness: 0.15, inverted: true)
    let png = try await chart { $0.grade = Grade(exposure: -2, window: window) }
    #expect(try GoldenFrame.matches(png, named: "grade-window", in: golden))
  }

  @Test
  func `grain speckles the chart`() async throws {
    let png = try await chart { $0.effects = Effects(grain: 1) }
    #expect(try GoldenFrame.matches(png, named: "effect-grain", in: golden))
  }

  @Test
  func `halation glows red around the highlights`() async throws {
    let png = try await chart { $0.effects = Effects(halation: 1) }
    #expect(try GoldenFrame.matches(png, named: "effect-halation", in: golden))
  }

  @Test
  func `a vignette darkens the corners`() async throws {
    let png = try await chart { $0.effects = Effects(vignette: 1) }
    #expect(try GoldenFrame.matches(png, named: "effect-vignette", in: golden))
  }

  @Test
  func `blur softens the edges`() async throws {
    let png = try await chart { $0.effects = Effects(blur: 0.5) }
    #expect(try GoldenFrame.matches(png, named: "effect-blur", in: golden))
  }

  @Test
  func `a chroma key shows the chart through the green`() async throws {
    let png = try await overChart(
      left: FixtureColor(red: 0, green: 255, blue: 0),
      right: FixtureColor(red: 240, green: 140, blue: 40),
    ) { $0.effects = Effects(key: ChromaKey()) }
    #expect(try GoldenFrame.matches(png, named: "effect-chroma-key", in: golden))
  }

  @Test(arguments: BlendMode.allCases)
  func `each blend mode mixes a layer with the chart`(mode: BlendMode) async throws {
    let png = try await overChart(
      left: FixtureColor(red: 230, green: 150, blue: 90),
      right: FixtureColor(red: 40, green: 60, blue: 120),
    ) { $0.blend = mode }
    #expect(try GoldenFrame.matches(
      png,
      named: "blend-\(mode.rawValue.lowercased())",
      in: golden,
    ))
  }

  // MARK: Private

  private let golden = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "Golden")

  /// The chart filling the frame, changed by `change`.
  private func chart(_ change: (inout Clip) -> Void) async throws -> Data {
    let chart = try await chartMedia()
    var clip = clip(of: chart)
    change(&clip)
    return try await render(Project(
      media: [chart],
      timeline: Timeline(format: .half, tracks: [Track(kind: .video, clips: [clip])]),
    ))
  }

  /// A smaller two-colour layer (`left` and `right` halves) over the chart, changed by `change`.
  private func overChart(
    left: FixtureColor,
    right: FixtureColor,
    change: (inout Clip) -> Void,
  ) async throws -> Data {
    let chart = try await chartMedia()
    let layer = try await Media(
      url: VideoFixture.make(left: left, right: right, width: 320, height: 240),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 240,
      hasAudio: false,
    )
    var top = clip(of: layer)
    top.transform.scale = 0.7
    change(&top)
    return try await render(Project(
      media: [chart, layer],
      timeline: Timeline(format: .half, tracks: [
        Track(kind: .video, clips: [clip(of: chart)]),
        Track(kind: .video, clips: [top]),
      ]),
    ))
  }

  private func chartMedia() async throws -> Media {
    try await Media(
      url: VideoFixture.makeChart(),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 240,
      hasAudio: false,
    )
  }

  private func clip(of media: Media) -> Clip {
    Clip(mediaID: media.id, sourceStart: .zero, duration: media.duration, timelineStart: .zero)
  }

  private func render(_ project: Project) async throws -> Data {
    try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
  }

}
