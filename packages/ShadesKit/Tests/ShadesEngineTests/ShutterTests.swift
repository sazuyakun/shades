import CoreGraphics
import ShadesCore
@testable import ShadesEngine
import Testing

/// Which moments of the shutter a moving layer is drawn at.
struct ShutterTests {

  // MARK: Internal

  @Test
  func `a layer that doesn't move is drawn once`() {
    let poses = Shutter.poses(around: second, length: 1 / 48, size: size, limit: 32) { _ in
      LayerPose(transform: ClipTransform(x: 0.2), camera: .identity)
    }
    #expect(poses.isEmpty)
  }

  @Test
  func `a sliding layer is drawn at evenly spaced moments centred on the frame`() throws {
    // why: 1 frame width a second across a 1/48 s shutter is 30 px: 20 steps of 1.5 px.
    let poses = Shutter.poses(around: second, length: 1 / 48, size: size, limit: 32, place: slide)
    #expect(poses.count == 20)
    let xs = poses.map(\.transform.x)
    #expect(abs(try #require(xs.first) + 1 / 96) < 0.0001)
    #expect(abs(try #require(xs.last) - 1 / 96) < 0.0001)
    let gaps = zip(xs, xs.dropFirst()).map { $1 - $0 }
    #expect(gaps.allSatisfy { abs($0 - (gaps.first ?? 0)) < 0.0001 })
  }

  @Test
  func `fast moves are capped and no shutter means no blur`() {
    let fast = Shutter.poses(around: second, length: 1 / 2, size: size, limit: 8, place: slide)
    #expect(fast.count == 8)
    #expect(Shutter.poses(around: second, length: 0, size: size, limit: 32, place: slide)
      .isEmpty)
  }

  @Test
  func `a camera move blurs layers that follow it`() {
    let poses = Shutter.poses(around: second, length: 1 / 48, size: size, limit: 32) { moment in
      LayerPose(transform: .identity, camera: ClipTransform(x: moment.seconds - 1))
    }
    #expect(poses.count == 20)
  }

  // MARK: Private

  private let size = CGSize(width: 1440, height: 1080)
  private let second = MediaTime(seconds: 1)

  /// Slides one frame width a second, centred at 1 s.
  private func slide(_ moment: MediaTime) -> LayerPose {
    LayerPose(transform: ClipTransform(x: moment.seconds - 1), camera: .identity)
  }

}
