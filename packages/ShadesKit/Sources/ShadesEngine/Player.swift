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

  /// Brings playback up to date with the project, keeping the playhead where it was. Only
  /// changes to clip timing or media rebuild playback; a clip's look, volume or a track's
  /// visibility update live.
  public func load(_ project: Project) async throws(EngineError) {
    let timeline = project.timeline
    duration = timeline.duration.seconds
    renderState.update(from: timeline)
    guard duration > 0 else {
      avPlayer.replaceCurrentItem(with: nil)
      composition = nil
      return
    }
    let structure = Composition.Structure(timeline)
    if structure == self.structure, let composition, let item = avPlayer.currentItem {
      item.audioMix = composition.audioMix(for: timeline)
      // why: a fresh copy of the video composition makes the player redraw the paused frame.
      item.videoComposition = composition.videoComposition.mutableCopy() as? AVVideoComposition
      return
    }
    let playhead = avPlayer.currentTime()
    let built = try await Composition.build(
      project,
      library: library,
      renderState: renderState,
      frameCounter: frameCounter,
    )
    // why: a newer edit started its own load while this one was building; it wins.
    guard !Task.isCancelled else {
      return
    }
    let item = AVPlayerItem(asset: built.asset)
    item.videoComposition = built.videoComposition
    item.audioMix = built.audioMix(for: timeline)
    avPlayer.replaceCurrentItem(with: item)
    composition = built
    self.structure = structure
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
  @ObservationIgnored private let library = MediaLibrary()
  @ObservationIgnored private let renderState = RenderState()
  @ObservationIgnored private var composition: Composition?
  @ObservationIgnored private var structure: Composition.Structure?

}
