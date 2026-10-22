import AVFoundation
import Foundation
import ShadesCore
import ShadesMatting
import ShadesTestSupport
import Testing

struct FlowMakerTests {

  // MARK: Internal

  @Test
  func `a square sliding right and down moves right and down, and the background stays still`()
    async throws
  {
    let source = try await VideoFixture.makeMovingSquare(seconds: 1, diagonal: true)
    let flow = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await FlowMaker.make(from: source, to: flow) { _ in }
    let asset = AVURLAsset(url: flow)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    #expect(Int(try await track.load(.naturalSize).width) == FlowMaker.width)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let image = try await generator.image(at: CMTime(value: 15, timescale: 30)).image
    let square = try speeds(in: image, x: 0.5, y: 0.5)
    // why: the square crosses a third of the frame each way in its one second.
    #expect(abs(square.across - 1 / 3) < 0.12)
    #expect(abs(square.down - 1 / 3) < 0.12)
    // why: still areas can drift a few stored steps (0.03 pictures a second each) through Vision
    // and the flow video; footage blur ignores motion that small.
    let corner = try speeds(in: image, x: 0.08, y: 0.1)
    #expect(abs(corner.across) < 0.15)
    #expect(abs(corner.down) < 0.15)
  }

  @Test
  func `a flat square sliding sideways has no streaks up or down at its corners`() async throws {
    let source = try await VideoFixture.makeMovingSquare(seconds: 1, isFlat: true)
    let flow = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
    try await FlowMaker.make(from: source, to: flow) { _ in }
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: flow))
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    let image = try await generator.image(at: CMTime(value: 15, timescale: 30)).image
    var steepest = 0.0
    for row in stride(from: 0.02, to: 1, by: 0.04) {
      for column in stride(from: 0.02, to: 1, by: 0.02) {
        steepest = try max(steepest, abs(speeds(in: image, x: column, y: row).down))
      }
    }
    // why: before the forward–backward check, Vision's guesses at the corners stored up to
    // ±3 pictures a second up or down; footage blur ignores motion under eight stored steps.
    #expect(steepest < 8 * 2 * FlowVideo.range / 255)
  }

  @Test
  func `stored speeds read back as the speeds written, clamped to the range`() {
    #expect(FlowVideo.value(of: 0) == 0.5)
    #expect(abs(FlowVideo.speed(of: FlowVideo.value(of: 1.5)) - 1.5) < 0.000_001)
    #expect(FlowVideo.value(of: 100) == 1)
  }

  // MARK: Private

  /// The speeds (pictures a second) stored at a point of a flow frame, read in the frame's own
  /// colour space so nothing is colour-matched.
  private func speeds(
    in image: CGImage,
    x: Double,
    y: Double,
  ) throws -> (across: Double, down: Double) {
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
      data: &pixel,
      width: 1,
      height: 1,
      bitsPerComponent: 8,
      bytesPerRow: 4,
      space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    ))
    let width = Double(image.width)
    let height = Double(image.height)
    context.draw(
      image,
      in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height),
    )
    return (
      FlowVideo.speed(of: Double(pixel[0]) / 255),
      FlowVideo.speed(of: Double(pixel[1]) / 255),
    )
  }

}
