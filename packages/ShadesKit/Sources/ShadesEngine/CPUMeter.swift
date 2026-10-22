import Synchronization

// MARK: - CPUMeter

/// How busy Shades keeps the processor, for the performance HUD and the idle gate: the share of
/// one core it used between readings.
public final class CPUMeter: Sendable {

  // MARK: Lifecycle

  public init() {
    last = Mutex(Reading())
  }

  // MARK: Public

  /// Percent of one core used since the last reading (or since the meter was made).
  public func usage() -> Double {
    let now = Reading()
    let before = last.withLock { last in
      let before = last
      last = now
      return before
    }
    let (seconds, attoseconds) = (now.time - before.time).components
    let wall = Double(seconds) + Double(attoseconds) * 1e-18
    return wall > 0 ? (now.processor - before.processor) / wall * 100 : 0
  }

  // MARK: Private

  private let last: Mutex<Reading>

}

// MARK: - Reading

/// The processor time used so far, and when it was read.
private struct Reading {
  let processor = SystemStats.processorSeconds()
  let time = ContinuousClock.now
}
