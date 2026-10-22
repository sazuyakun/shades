import Foundation
import ShadesEngine
import Testing

struct CPUMeterTests {
  @Test
  func `busy work reads as at least most of a core`() {
    let meter = CPUMeter()
    let clock = ContinuousClock()
    let end = clock.now + .milliseconds(300)
    var spins = 0
    while clock.now < end {
      spins &+= 1
    }
    // why: the meter reads the whole process, so tests running alongside only add to it; the
    // idle reading is checked by the serialized performance gate.
    #expect(meter.usage() > 50, "after \(spins) spins")
  }
}
