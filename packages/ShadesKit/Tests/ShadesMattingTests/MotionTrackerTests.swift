import CoreGraphics
import Foundation
import ShadesMatting
import ShadesTestSupport
import Testing

struct MotionTrackerTests {
  @Test
  func `a tracked square is followed as it slides across the picture`() async throws {
    let video = try await VideoFixture.makeMovingSquare(seconds: 2)
    let side = 0.3 * 360 / 640
    let path = try await MotionTracker.track(
      in: video,
      box: CGRect(x: 1.0 / 3 - side / 2, y: 0.35, width: side, height: 0.3),
      from: 0,
      to: 2,
    ) { _ in }
    let first = try #require(path.first)
    let last = try #require(path.last)
    #expect(path.count > 40)
    #expect(abs(first.x - 1.0 / 3) < 0.03)
    #expect(abs(last.x - 2.0 / 3) < 0.05)
    #expect(path.allSatisfy { abs($0.y - 0.5) < 0.05 })
  }

  @Test
  func `an empty box can't be tracked`() async throws {
    let video = try await VideoFixture.make(red: 20, green: 20, blue: 20, seconds: 1)
    await #expect(throws: MattingError.trackingFailed) {
      try await MotionTracker.track(
        in: video,
        box: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
        from: 0,
        to: 1,
      ) { _ in }
    }
  }
}
