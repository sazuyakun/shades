import Synchronization

// MARK: - FrameCounter

/// Watches the frames the compositor draws, for the performance HUD and the preview's Auto
/// quality: how many a second, how long each takes, how many playback skipped, and how long a
/// scrub or an edit waited for its frame.
public final class FrameCounter: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// Frames drawn during the last second.
  public var framesPerSecond: Int {
    let now = ContinuousClock.now
    return state.withLock { state in
      state.recent.count { now - $0.drawnAt <= .seconds(1) }
    }
  }

  /// How long the last second's frames took to draw, on average, or zero when none were.
  public var frameTime: Duration {
    let now = ContinuousClock.now
    let times = state.withLock { state in
      state.recent.filter { now - $0.drawnAt <= .seconds(1) }.map(\.took)
    }
    return times.isEmpty ? .zero : times.reduce(.zero, +) / times.count
  }

  /// Frames skipped while playing at normal speed, since the counter was made.
  public var droppedFrames: Int {
    state.withLock { $0.dropped }
  }

  /// How long the last scrub waited for its frame.
  public var scrubLatency: Duration? {
    state.withLock { $0.scrubLatency }
  }

  /// How long the last edit waited for its frame.
  public var editLatency: Duration? {
    state.withLock { $0.editLatency }
  }

  // MARK: Internal

  /// What a frame was drawn for, when something waits on it.
  enum Wait {
    case scrub
    case edit
  }

  /// Records that the frame at `time` (seconds into the timeline) was just drawn in `took`.
  func recordFrame(at time: Double, took: Duration) {
    let now = ContinuousClock.now
    state.withLock { state in
      state.recent.append(DrawnFrame(drawnAt: now, took: took))
      state.recent.removeAll { now - $0.drawnAt > .seconds(1) }
      if let frameDuration = state.playingFrameDuration, let last = state.lastTime {
        let step = Int(((time - last) / frameDuration).rounded())
        // why: a step back or of more than a second is a seek, not frames left out.
        if step > 1, Double(step) * frameDuration <= 1 {
          state.dropped += step - 1
        }
      }
      state.lastTime = time
      for (wait, since) in state.waits {
        switch wait {
        case .scrub: state.scrubLatency = now - since
        case .edit: state.editLatency = now - since
        }
      }
      state.waits.removeAll()
    }
  }

  /// Starts counting skipped frames: playback runs at normal speed, a frame every
  /// `frameDuration` seconds.
  func playbackStarted(frameDuration: Double) {
    state.withLock { state in
      state.playingFrameDuration = frameDuration
      state.lastTime = nil
    }
  }

  /// Stops counting skipped frames: playback paused or runs at another speed.
  func playbackStopped() {
    state.withLock { $0.playingFrameDuration = nil }
  }

  /// Times how long until the next frame is drawn, as the latency of `wait`, from `since`.
  func expectFrame(for wait: Wait, since: ContinuousClock.Instant) {
    state.withLock { $0.waits[wait] = since }
  }

  // MARK: Private

  private let state = Mutex(CounterState())

}

// MARK: - CounterState

/// What `FrameCounter` keeps between frames.
private struct CounterState {
  var recent = [DrawnFrame]()
  var dropped = 0
  /// While playing at normal speed, how far apart frames should be.
  var playingFrameDuration: Double?
  /// The timeline time of the last frame drawn.
  var lastTime: Double?
  var waits = [FrameCounter.Wait: ContinuousClock.Instant]()
  var scrubLatency: Duration?
  var editLatency: Duration?
}

// MARK: - DrawnFrame

/// When a frame was drawn and how long it took.
private struct DrawnFrame {
  let drawnAt: ContinuousClock.Instant
  let took: Duration
}
