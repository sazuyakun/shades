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
        self?.watchPlayback()
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
  /// Each track's level as it plays, for the mixer's meters.
  @ObservationIgnored public let meters = MixMeters()

  /// The playhead position in seconds.
  public private(set) var currentTime: Double = 0
  /// The timeline length in seconds.
  public private(set) var duration: Double = 0
  public private(set) var isPlaying = false
  /// Light editing copies to play instead of heavy originals, by media. Set them, then `load`.
  public var proxies = [Media.ID: URL]()
  /// Cut-outs by media, for depth slots (text behind a person). Set them, then `load`.
  public var mattes = [Media.ID: URL]()
  /// Optical flow by media, for footage motion blur. Set them, then `load`.
  public var flows = [Media.ID: URL]()
  /// Noise-reduced sound by media, for clips set to clean sound. Set them, then `load`.
  public var cleanSound = [Media.ID: URL]()
  /// Stereo copies of mono sound by media, so panned tracks can pan it. Set them, then `load`.
  public var stereoSound = [Media.ID: URL]()
  /// Whether what's playing now uses any proxy, for the viewer's "Proxy" badge.
  public private(set) var isUsingProxies = false

  /// How fast playback runs: 1 is normal, 2 double speed, −1 backwards.
  public private(set) var rate: Float = 1

  /// Whether playback is drawn at half size right now, for the viewer's "Half" badge.
  public private(set) var isHalfSize = false

  /// How big playback frames are drawn. Exports and frames for Claude are always full size.
  public var previewQuality = PreviewQuality.auto {
    didSet { showPreviewSize() }
  }

  /// Brings playback up to date with the project, keeping the playhead where it was. Only
  /// changes to clip timing or media rebuild playback; a clip's look, volume or a track's
  /// visibility update live.
  public func load(_ project: Project) async throws(EngineError) {
    let requested = ContinuousClock.now
    let timeline = project.timeline
    duration = timeline.duration.seconds
    frameDuration = 1 / Double(timeline.format.framesPerSecond)
    renderState.update(from: timeline)
    guard duration > 0 else {
      avPlayer.replaceCurrentItem(with: nil)
      composition = nil
      return
    }
    let structure = Composition.Structure(timeline)
    if
      structure == self.structure, proxies == loadedProxies, mattes == loadedMattes,
      flows == loadedFlows,
      cleanSound == loadedCleanSound,
      stereoSound == loadedStereoSound,
      let composition,
      let item = avPlayer.currentItem
    {
      item.audioMix = composition.audioMix(for: timeline, meters: meters)
      // why: a fresh copy of the video composition makes the player redraw the paused frame.
      item.videoComposition = sized(composition)
      frameCounter.expectFrame(for: .edit, since: requested)
      if let cuedTime {
        self.cuedTime = nil
        await seek(toSeconds: cuedTime)
      }
      return
    }
    let isEdit = composition != nil
    let current = avPlayer.currentTime()
    // why: with nothing loaded yet the player's time is invalid (NaN seconds); start at zero.
    cuedTime = cuedTime ?? (current.isNumeric ? current.seconds : 0)
    let built = try await Composition.build(
      project,
      library: library,
      renderState: renderState,
      renderContext: renderContext(),
      frameCounter: frameCounter,
      quality: .preview,
      sources: proxies,
      mattes: mattes,
      flows: flows,
      cleanSound: cleanSound,
      stereoSound: stereoSound,
    )
    // why: a newer edit started its own load while this one was building; it wins.
    guard !Task.isCancelled else {
      return
    }
    fellBehind = false
    let item = AVPlayerItem(asset: built.asset)
    item.videoComposition = sized(built)
    item.audioMix = built.audioMix(for: timeline, meters: meters)
    item.audioTimePitchAlgorithm = Composition.timePitchAlgorithm
    // why: the sound runs on silently past the end (see `Composition.runOn`); playback stops there.
    item.forwardPlaybackEndTime = timeline.duration.cmTime
    avPlayer.replaceCurrentItem(with: item)
    composition = built
    self.structure = structure
    loadedProxies = proxies
    loadedMattes = mattes
    loadedFlows = flows
    loadedCleanSound = cleanSound
    loadedStereoSound = stereoSound
    isUsingProxies = timeline.allClips.contains { $0.mediaID.flatMap { proxies[$0] } != nil }
    // why: read after building, so a seek made while it built lands, not the time before it.
    let playhead = CMTime(seconds: min(cuedTime ?? 0, duration), preferredTimescale: 600)
    cuedTime = nil
    if isEdit {
      frameCounter.expectFrame(for: .edit, since: requested)
    }
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
    playbackChanged()
  }

  public func pause() {
    avPlayer.pause()
    isPlaying = false
    playbackChanged()
  }

  public func togglePlayback() {
    isPlaying ? pause() : play()
  }

  /// Moves the playhead to an exact time. While a project is loading, it's where the load ends.
  public func seek(toSeconds seconds: Double) async {
    guard cuedTime == nil else {
      cue(toSeconds: max(seconds, 0))
      return
    }
    let time = CMTime(seconds: min(max(seconds, 0), duration), preferredTimescale: 600)
    frameCounter.expectFrame(for: .scrub, since: .now)
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
  /// Where the playhead goes when the load under way (or the next one) finishes.
  @ObservationIgnored private var cuedTime: Double?
  @ObservationIgnored private var loadedProxies = [Media.ID: URL]()
  @ObservationIgnored private var loadedMattes = [Media.ID: URL]()
  @ObservationIgnored private var loadedFlows = [Media.ID: URL]()
  @ObservationIgnored private var loadedCleanSound = [Media.ID: URL]()
  @ObservationIgnored private var loadedStereoSound = [Media.ID: URL]()
  @ObservationIgnored private var sharedContext: RenderContext?
  /// Seconds between frames on the loaded timeline.
  @ObservationIgnored private var frameDuration = 1.0 / 24
  /// Whether frames fell behind while playing at full size since playback was last rebuilt;
  /// Auto then plays at half size.
  @ObservationIgnored private var fellBehind = false
  /// Frames playback had skipped when it last started, to tell when it skips more.
  @ObservationIgnored private var droppedAtStart = 0

  /// Whether frames should be drawn at half size right now.
  private var wantsHalfSize: Bool {
    switch previewQuality {
    case .full: false
    case .half: true
    case .auto: isPlaying && fellBehind
    }
  }

  /// `composition`'s frames at the size the preview quality asks for now.
  private func sized(_ composition: Composition) -> AVVideoComposition? {
    isHalfSize = wantsHalfSize
    guard let copy = composition.videoComposition.mutableCopy() as? AVMutableVideoComposition
    else {
      return nil
    }
    if isHalfSize {
      // why: video sizes stay even, as encoders and pixel buffers expect.
      copy.renderSize = CGSize(
        width: (copy.renderSize.width / 4).rounded(.down) * 2,
        height: (copy.renderSize.height / 4).rounded(.down) * 2,
      )
    }
    return copy
  }

  /// Draws at the size the preview quality asks for, when that changed.
  private func showPreviewSize() {
    guard wantsHalfSize != isHalfSize, let composition, let item = avPlayer.currentItem else {
      return
    }
    item.videoComposition = sized(composition)
  }

  /// Keeps up with the player: whether it's still playing (it stops at the end), and for Auto,
  /// whether frames have started falling behind.
  private func watchPlayback() {
    let isPlaying = avPlayer.rate != 0
    if isPlaying != self.isPlaying {
      self.isPlaying = isPlaying
      playbackChanged()
    }
    let isBehind = frameCounter.droppedFrames > droppedAtStart
      || frameCounter.frameTime > .seconds(frameDuration)
    if previewQuality == .auto, isPlaying, !isHalfSize, isBehind {
      fellBehind = true
      showPreviewSize()
    }
  }

  /// Counts skipped frames while playing at normal speed, and sizes frames for the new state.
  private func playbackChanged() {
    if isPlaying, rate == 1 {
      droppedAtStart = frameCounter.droppedFrames
      frameCounter.playbackStarted(frameDuration: frameDuration)
    } else {
      frameCounter.playbackStopped()
    }
    showPreviewSize()
  }

}
