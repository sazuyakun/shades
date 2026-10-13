import Synchronization

/// Counts how many frames the compositor drew in the last second, for the performance HUD.
public final class FrameCounter: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// Frames drawn during the last second.
  public var framesPerSecond: Int {
    let now = ContinuousClock.now
    return recentFrames.withLock { frames in
      frames.count { now - $0 <= .seconds(1) }
    }
  }

  // MARK: Internal

  /// Records that a frame was just drawn.
  func recordFrame() {
    let now = ContinuousClock.now
    recentFrames.withLock { frames in
      frames.append(now)
      frames.removeAll { now - $0 > .seconds(1) }
    }
  }

  // MARK: Private

  private let recentFrames = Mutex<[ContinuousClock.Instant]>([])

}
