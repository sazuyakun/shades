import CoreGraphics
import Foundation
import ImageIO
import ShadesCore
import ShadesEngine
import ShadesTestSupport
import Testing

@MainActor
struct FrameRendererTests {

  // MARK: Internal

  @Test
  func `a rendered frame shows the clip's color`() async throws {
    let project = try await makeProject(red: 255, green: 0, blue: 0)
    let png = try await FrameRenderer.png(of: project, atSeconds: 0.5, maxSide: 320)
    let (red, green, blue) = try centerPixel(of: png)
    #expect(red > 200)
    #expect(green < 60)
    #expect(blue < 60)
  }

  @Test
  func `rendering an empty timeline throws timelineEmpty`() async {
    await #expect(throws: EngineError.timelineEmpty) {
      try await FrameRenderer.png(of: Project(), atSeconds: 0, maxSide: 320)
    }
  }

  // MARK: Private

  /// A project whose timeline is one 1-second clip of a solid color.
  private func makeProject(red: UInt8, green: UInt8, blue: UInt8) async throws -> Project {
    let url = try await VideoFixture.make(red: red, green: green, blue: blue)
    let media = Media(
      url: url,
      duration: MediaTime(seconds: 1),
      width: 320,
      height: 180,
      hasAudio: false,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    return Project(media: [media], timeline: Timeline(tracks: [Track(name: "V1", clips: [clip])]))
  }

  /// Decodes a PNG and returns the RGB of its middle pixel.
  private func centerPixel(of png: Data) throws -> (UInt8, UInt8, UInt8) {
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
      data: &pixel,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ))
    let x = -Double(image.width / 2)
    let y = -Double(image.height / 2)
    context.draw(
      image,
      in: CGRect(x: x, y: y, width: Double(image.width), height: Double(image.height)),
    )
    return (pixel[0], pixel[1], pixel[2])
  }

}
