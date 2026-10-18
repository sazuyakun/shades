import AVFoundation
import Foundation
import ShadesMatting
import ShadesTestSupport
import Testing

struct MatteMakerTests {

  // MARK: Internal

  @Test
  func `the foreground engine cuts out an obvious subject, frame for frame`() async throws {
    let source = try await VideoFixture.makeDisc(seconds: 1)
    let matte = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await MatteMaker.make(from: source, to: matte, engine: .visionForeground) { _ in }
    let asset = AVURLAsset(url: matte)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let size = try await track.load(.naturalSize)
    #expect(Int(size.width) == MatteMaker.width)
    let frames = try await track.load(.timeRange).duration
      .seconds * Double(try await track.load(.nominalFrameRate))
    #expect(abs(frames - 30) <= 2)
    let image = try await AVAssetImageGenerator(asset: asset).image(at: CMTime(
      value: 15,
      timescale: 30,
    )).image
    #expect(try brightness(of: image, x: 0.5, y: 0.5) > 200)
    #expect(try brightness(of: image, x: 0.05, y: 0.05) < 40)
  }

  // MARK: Private

  private func brightness(of image: CGImage, x: Double, y: Double) throws -> UInt8 {
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
    let width = Double(image.width)
    let height = Double(image.height)
    context.draw(
      image,
      in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height),
    )
    return pixel[0]
  }

}
