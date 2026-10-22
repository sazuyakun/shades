import CoreGraphics
import Foundation
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

/// Where a layer's picture lands in the frame, and back, as the shader draws it.
struct LayerProjectionTests {

  // MARK: Internal

  @Test
  func `a box over a letterboxed picture lands in the picture's own fractions`() throws {
    let projection = try place(Clip(
      mediaID: wide.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    ))
    let box = projection.pictureBox(under: CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.375))
    #expect(abs(box.minX - 0.25) < 0.0001)
    #expect(abs(box.minY) < 0.0001)
    #expect(abs(box.height - 0.5) < 0.0001)
  }

  @Test
  func `a moved, zoomed picture is undone`() throws {
    var clip = Clip(
      mediaID: wide.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    clip.transform.scale = 2
    clip.transform.x = 0.25
    let box = try place(clip).pictureBox(under: CGRect(x: 0.75, y: 0.5, width: 0.1, height: 0.1))
    #expect(abs(box.minX - 0.5) < 0.0001)
    #expect(abs(box.width - 0.05) < 0.0001)
  }

  @Test
  func `the part outside the picture is cut off`() throws {
    let clip = Clip(
      mediaID: wide.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    let box = try place(clip).pictureBox(under: CGRect(x: 0, y: 0, width: 1, height: 0.1))
    #expect(box.isEmpty)
  }

  @Test
  func `the camera's zoom and a 3D tilt move points, and picture points come back exactly`()
    throws
  {
    var clip = Clip(
      mediaID: wide.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    let flat = try #require(try place(clip).framePoint(of: CGPoint(x: 0.75, y: 0.5)))
    let zoomed = try #require(try place(clip, camera: [
      Keyframe(property: .scale, time: .zero, value: 2)
    ]).framePoint(of: CGPoint(x: 0.75, y: 0.5)))
    #expect(abs((zoomed.x - 0.5) - 2 * (flat.x - 0.5)) < 0.0001)
    clip.transform.tiltY = 40
    clip.transform.rotation = 15
    let tilted = try place(clip)
    for point in [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.9, y: 0.7), CGPoint(x: 0.5, y: 0.5)] {
      let frame = try #require(tilted.framePoint(of: point))
      let back = try #require(tilted.picturePoint(at: frame))
      #expect(abs(back.x - point.x) < 0.0001 && abs(back.y - point.y) < 0.0001)
    }
  }

  @Test
  func `a tilted layer under a camera move is drawn where its projection says`() async throws {
    let red = try await solid(FixtureColor(red: 255, green: 0, blue: 0))
    let blue = try await solid(FixtureColor(red: 0, green: 0, blue: 255))
    var top = Clip(mediaID: blue.id, sourceStart: .zero, duration: seconds(1), timelineStart: .zero)
    top.transform = ClipTransform(x: 0.1, scale: 0.6, rotation: 10, tiltY: 35)
    let project = Project(
      media: [red, blue],
      timeline: Timeline(
        format: .half,
        tracks: [
          Track(kind: .video, clips: [
            Clip(mediaID: red.id, sourceStart: .zero, duration: seconds(1), timelineStart: .zero)
          ]),
          Track(kind: .video, clips: [top]),
        ],
        camera: [Keyframe(property: .scale, time: .zero, value: 1.2)],
      ),
    )
    let projection = try #require(RenderContext().projection(of: top, in: project, at: .zero))
    let png = try await FrameRenderer.png(of: project, atSeconds: 0, maxSide: 320)
    for (inside, outside) in [(0.06, -0.06), (0.94, 1.06)] {
      let near = try #require(projection.framePoint(of: CGPoint(x: inside, y: 0.5)))
      let far = try #require(projection.framePoint(of: CGPoint(x: outside, y: 0.5)))
      #expect(try PixelProbe.color(of: png, x: near.x, y: near.y).blue > 200)
      #expect(try PixelProbe.color(of: png, x: far.x, y: far.y).red > 200)
    }
  }

  @Test
  func `text is placed at its own size, where its words sit`() throws {
    let caption = Clip(
      source: .text(TextContent(text: "Hello Shades")),
      sourceStart: .zero,
      duration: seconds(1),
      timelineStart: .zero,
    )
    let project = Project(timeline: Timeline(format: .half, tracks: [
      Track(kind: .text, clips: [caption])
    ]))
    let projection = try #require(RenderContext().projection(of: caption, in: project, at: .zero))
    let centre = try #require(projection.framePoint(of: CGPoint(x: 0.5, y: 0.5)))
    let left = try #require(projection.framePoint(of: CGPoint(x: 0, y: 0.5)))
    #expect(centre.y > 0.7, "a caption sits near the bottom")
    #expect(abs(centre.x - 0.5) < 0.01 && left.x > 0.05, "narrower than the frame")
  }

  // MARK: Private

  /// A 16:9 picture, fitted inside the 4:3 frame with bars above and below.
  private let wide = Media(
    url: URL(filePath: "/tmp/wide.mov"),
    duration: MediaTime(seconds: 5),
    width: 1920,
    height: 1080,
    hasAudio: false,
  )

  private func place(_ clip: Clip, camera: [Keyframe] = []) throws -> LayerProjection {
    let project = Project(media: [wide], timeline: Timeline(
      format: VideoFormat(width: 2880, height: 2160, framesPerSecond: 24),
      tracks: [Track(kind: .video, clips: [clip])],
      camera: camera,
    ))
    return try #require(try RenderContext().projection(of: clip, in: project, at: .zero))
  }

  private func solid(_ color: FixtureColor) async throws -> Media {
    try await Media(
      url: VideoFixture.make(left: color, right: color, width: 320, height: 240),
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 240,
      hasAudio: false,
    )
  }

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

}
