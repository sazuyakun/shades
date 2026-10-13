import AVFoundation
import Observation
import ShadesCore

/// Plays the timeline. Views read its state; the viewer shows `avPlayer`.
@MainActor
@Observable
public final class Player {

  // MARK: Lifecycle

  public init() {
    timeObserver = avPlayer.addPeriodicTimeObserver(
      forInterval: CMTime(value: 1, timescale: 30),
      queue: .main,
    ) { [weak self] time in
      MainActor.assumeIsolated {
        self?.currentTime = time.seconds
        self?.isPlaying = self?.avPlayer.rate != 0
      }
    }
  }

  isolated deinit {
    if let timeObserver {
      avPlayer.removeTimeObserver(timeObserver)
    }
  }

  // MARK: Public

  @ObservationIgnored public let avPlayer = AVPlayer()
  public let frameCounter = FrameCounter()

  /// The playhead position in seconds.
  public private(set) var currentTime: Double = 0
  /// The timeline length in seconds.
  public private(set) var duration: Double = 0
  public private(set) var isPlaying = false

  /// Rebuilds playback from the project, keeping the playhead where it was.
  public func load(_ project: Project) async throws(EngineError) {
    duration = project.timeline.duration.seconds
    guard duration > 0 else {
      avPlayer.replaceCurrentItem(with: nil)
      return
    }
    let playhead = avPlayer.currentTime()
    let composition = try await Composition.build(project, frameCounter: frameCounter)
    let item = AVPlayerItem(asset: composition.asset)
    item.videoComposition = composition.videoComposition
    avPlayer.replaceCurrentItem(with: item)
    await avPlayer.seek(to: playhead, toleranceBefore: .zero, toleranceAfter: .zero)
  }

  public func play() {
    avPlayer.play()
    isPlaying = true
  }

  public func pause() {
    avPlayer.pause()
    isPlaying = false
  }

  public func togglePlayback() {
    isPlaying ? pause() : play()
  }

  /// Moves the playhead to an exact time.
  public func seek(toSeconds seconds: Double) async {
    let time = CMTime(seconds: min(max(seconds, 0), duration), preferredTimescale: 600)
    await avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    currentTime = time.seconds
  }

  // MARK: Private

  @ObservationIgnored private var timeObserver: Any?

}
