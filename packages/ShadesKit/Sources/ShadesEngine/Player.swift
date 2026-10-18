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
        // why: while an item loads the player reports an invalid time; keep the last good one.
        if time.seconds.isFinite {
          self?.currentTime = time.seconds
        }
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
  /// Light editing copies to play instead of heavy originals, by media. Set them, then `load`.
  public var proxies = [Media.ID: URL]()
  /// Cut-outs by media, for depth slots (text behind a person). Set them, then `load`.
  public var mattes = [Media.ID: URL]()
  /// Whether what's playing now uses any proxy, for the viewer's "Proxy" badge.
  public private(set) var isUsingProxies = false

  /// How fast playback runs: 1 is normal, 2 double speed, −1 backwards.
  public private(set) var rate: Float = 1

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
    if
      structure == self.structure, proxies == loadedProxies, let composition,
      let item = avPlayer.currentItem
    {
      item.audioMix = composition.audioMix(for: timeline)
      // why: a fresh copy of the video composition makes the player redraw the paused frame.
      item.videoComposition = composition.videoComposition.mutableCopy() as? AVVideoComposition
      return
    }
    let current = avPlayer.currentTime()
    // why: with nothing loaded yet the player's time is invalid (NaN seconds); start at zero.
    let playhead = cuedTime.map { CMTime(seconds: $0, preferredTimescale: 600) }
      ?? (current.isNumeric ? current : .zero)
    cuedTime = nil
    let built = try await Composition.build(
      project,
      library: library,
      renderState: renderState,
      renderContext: renderContext(),
      frameCounter: frameCounter,
      sources: proxies,
      mattes: mattes,
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
    loadedProxies = proxies
    loadedMattes = mattes
    isUsingProxies = timeline.allClips.contains { $0.mediaID.flatMap { proxies[$0] } != nil }
    await avPlayer.seek(to: playhead, toleranceBefore: .zero, toleranceAfter: .zero)
    currentTime = playhead.seconds
  }

  /// Sets where the playhead goes when the next project loads, e.g. where the user left off.
  public func cue(toSeconds seconds: Double) {
    cuedTime = seconds
    currentTime = seconds
  }

  public func play() {
    play(atRate: 1)
  }

  /// Plays at `rate`; backwards only if the footage allows it.
  public func play(atRate rate: Float) {
    guard rate > 0 || avPlayer.currentItem?.canPlayReverse == true else {
      return
    }
    self.rate = rate
    avPlayer.rate = rate
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

  /// The GPU setup, made the first time it's needed, shared with frame grabs for Claude.
  public func renderContext() throws(EngineError) -> RenderContext {
    if let sharedContext {
      return sharedContext
    }
    let context = try RenderContext()
    sharedContext = context
    return context
  }

  // MARK: Private

  @ObservationIgnored private var timeObserver: Any?
  @ObservationIgnored private let library = MediaLibrary()
  @ObservationIgnored private let renderState = RenderState()
  @ObservationIgnored private var composition: Composition?
  @ObservationIgnored private var structure: Composition.Structure?
  @ObservationIgnored private var cuedTime: Double?
  @ObservationIgnored private var loadedProxies = [Media.ID: URL]()
  @ObservationIgnored private var loadedMattes = [Media.ID: URL]()
  @ObservationIgnored private var sharedContext: RenderContext?

}
