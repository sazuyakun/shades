import ShadesCore
@testable import ShadesEngine
import Testing

struct DepthOrderTests {
  @Test
  func `without a cut-out, layers draw in track order`() {
    let order = DepthOrder.steps(
      depths: [.inFront, .behindSubject, .inFront],
      hasMatte: [false, false, false],
    )
    #expect(order.steps == [.plain(0), .plain(1), .plain(2)])
    #expect(order.maskBase == nil)
  }

  @Test
  func `text behind the subject goes between the background and the cut-out`() {
    // V1 (with a cut-out), T1 behind the subject, T2 in front.
    let order = DepthOrder.steps(
      depths: [.inFront, .behindSubject, .inFront],
      hasMatte: [true, false, false],
    )
    #expect(order.steps == [.plain(0), .plain(1), .cutOut(0), .plain(2)])
    #expect(order.maskBase == 0)
  }

  @Test
  func `a replacement background takes the base's place and inside layers are masked`() {
    let order = DepthOrder.steps(
      depths: [.inFront, .replaceBackground, .insideSubject],
      hasMatte: [true, false, false],
    )
    #expect(order.steps == [.plain(1), .cutOut(0), .masked(2)])
  }

  @Test
  func `a cut-out with only in-front layers above draws normally`() {
    let order = DepthOrder.steps(depths: [.inFront, .inFront], hasMatte: [true, false])
    #expect(order.steps == [.plain(0), .plain(1)])
    #expect(order.maskBase == nil)
  }
}
