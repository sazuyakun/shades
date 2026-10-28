import AVFoundation
import ShadesCore

// MARK: - MixReader

/// Reads a project's finished sound mix (every track, with volumes, fades, ducking and the
/// master level) as stereo samples, a stretch at a time. Reading blocks while audio decodes, so
/// the reader runs on its own dispatch queue, never on Swift's thread pool.
public actor MixReader {

  // MARK: Lifecycle

  /// A reader for `project`'s mix, read from the original media (or `cleanSound`, the
  /// noise-reduced sound, for clips set to use it), over `range` of the timeline (all of it by
  /// default).
  public init(
    project: Project,
    cleanSound: [Media.ID: URL] = [:],
    stereoSound: [Media.ID: URL] = [:],
    range: TimeRange? = nil,
  ) {
    self.project = project
    self.cleanSound = cleanSound
    self.stereoSound = stereoSound
    self.range = range
  }

  // MARK: Public

  /// Samples a second: what the mix is read at.
  public static let sampleRate = 48000.0

  nonisolated public var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  /// The next stretch of the mix as interleaved left/right samples, or `nil` at its end.
  public func nextChunk() async throws(EngineError) -> [Float]? {
    if reader == nil {
      try await start()
    }
    while framesLeft > 0 {
      for index in lanes.indices where lanes[index].pending.isEmpty && !lanes[index].isDone {
        if let samples = try read(lanes[index].output) {
          lanes[index].pending += samples
        } else {
          lanes[index].isDone = true
        }
      }
      let reading = lanes.filter { !$0.isDone }
      let frames = min(
        framesLeft,
        reading.isEmpty
          ? lanes.lazy.map { $0.pending.count / 2 }.max() ?? 0
          : reading.lazy.map { $0.pending.count / 2 }.min() ?? 0,
      )
      guard frames > 0 || !reading.isEmpty else {
        return nil
      }
      if frames > 0 {
        return mix(frames)
      }
    }
    return nil
  }

  // MARK: Private

  /// One track's sound as it's read: its own output, how to pan it, and samples read but not
  /// mixed yet.
  private struct Lane {
    let output: AVAssetReaderAudioMixOutput
    let shaping: SoundShaping
    /// Where its clips play stereo sound, in timeline seconds: the only sound pan moves.
    let stereo: [ClosedRange<Double>]
    var pending = [Float]()
    var isDone = false
  }

  private nonisolated let queue = DispatchSerialQueue(label: "com.sazuyakun.shades.mix")
  private let project: Project
  private let cleanSound: [Media.ID: URL]
  private let stereoSound: [Media.ID: URL]
  private let range: TimeRange?
  private var reader: AVAssetReader?
  private var lanes = [Lane]()
  /// The master limiter, applied to the summed mix.
  private var limiter = SoundShaping(limiter: [], pan: 0)
  /// How many frames have been handed out, and how many more belong to the timeline (the
  /// run-on past its end isn't the mix).
  private var framesRead = 0
  private var framesLeft = 0

  /// `frames` frames of every lane, each panned, summed and limited.
  private func mix(_ frames: Int) -> [Float] {
    var samples = [Float](repeating: 0, count: frames * 2)
    for index in lanes.indices {
      let lane = lanes[index]
      let count = min(frames, lane.pending.count / 2)
      for frame in 0 ..< count {
        let time = Double(framesRead + frame) / Self.sampleRate
        let isStereo = lane.stereo.contains { $0.contains(time) }
        samples[frame * 2] += lane.pending[frame * 2] * (isStereo ? lane.shaping.left : 1)
        samples[frame * 2 + 1] += lane.pending[frame * 2 + 1] * (isStereo ? lane.shaping.right : 1)
      }
      lanes[index].pending.removeFirst(count * 2)
    }
    if limiter.isLimiting {
      for frame in 0 ..< frames {
        let gain = limiter.limiterGain(at: Double(framesRead + frame) / Self.sampleRate)
        samples[frame * 2] *= gain
        samples[frame * 2 + 1] *= gain
      }
    }
    framesRead += frames
    framesLeft -= frames
    return samples
  }

  /// The next buffer of `output` as interleaved samples, or `nil` at its end.
  private func read(_ output: AVAssetReaderAudioMixOutput) throws(EngineError) -> [Float]? {
    guard let sample = output.copyNextSampleBuffer() else {
      // why: a reader that fails stops like one that's done; reading on would pass off a cut
      // mix as complete.
      if let error = reader?.error {
        let code = (error as NSError).code
        logger.error("mix.readFailed reason=reader code=\(code, privacy: .public)")
        throw .renderFailed
      }
      return nil
    }
    guard let block = CMSampleBufferGetDataBuffer(sample) else {
      return []
    }
    let length = CMBlockBufferGetDataLength(block)
    var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
    let status = samples.withUnsafeMutableBytes { bytes in
      bytes.baseAddress.map { CMBlockBufferCopyDataBytes(
        block,
        atOffset: 0,
        dataLength: length,
        destination: $0,
      ) }
        ?? kCMBlockBufferBadCustomBlockSourceErr
    }
    guard status == kCMBlockBufferNoErr else {
      logger.error("mix.readFailed status=\(status, privacy: .public)")
      throw .renderFailed
    }
    return samples
  }

  /// Lays every track's sound out in a composition and starts reading each track on its own
  /// through the mix's volumes; `mix(_:)` pans, sums and limits them. The pan and limiter aren't
  /// left to the mix's audio taps: reading a mix back skips ahead when a tap call runs long.
  private func start() async throws(EngineError) {
    let timeline = project.timeline
    let composition = AVMutableComposition()
    var trackIDs = [Track.ID: CMPersistentTrackID]()
    var stereo = [Track.ID: [ClosedRange<Double>]]()
    var lastSounds = [AVMutableCompositionTrack: AVAssetTrack]()
    // why: a track doesn't keep its asset alive, and can't be inserted once the asset is gone;
    // the run-on inserts the last sounds again after the loop.
    var assets = [AVURLAsset]()
    for track in timeline.tracks where track.kind != .text {
      var target: AVMutableCompositionTrack?
      for clip in track.clips {
        guard
          let mediaID = clip.mediaID,
          let media = project.media(withID: mediaID), media.hasAudio, !clip.isFrozen
        else {
          continue
        }
        let asset = AVURLAsset(
          url: Composition.sound(of: clip, cleanSound: cleanSound, stereoSound: stereoSound)
            ?? media.url
        )
        assets.append(asset)
        do {
          guard let audio = try await asset.loadTracks(withMediaType: .audio).first else {
            continue
          }
          let destination = try target ?? Composition.addTrack(.audio, to: composition)
          target = destination
          trackIDs[track.id] = destination.trackID
          for piece in MediaPiece.pieces(of: clip, frame: timeline.format.frameDuration) {
            try piece.insert(from: audio, into: destination)
          }
          let formats = try await audio.load(.formatDescriptions)
          if
            formats.contains(where: { format in
              (CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee.mChannelsPerFrame
                ?? 0) >= 2
            })
          {
            stereo[track.id, default: []].append(
              clip.timelineStart.seconds ... clip.timelineEnd.seconds
            )
          }
          if Composition.runsOn(clip, in: timeline) {
            lastSounds[destination] = audio
          }
        } catch {
          let code = (error as NSError).code
          let path = media.url.path
          logger.error("mix.readFailed reason=insert code=\(code) path=\(path, privacy: .private)")
          throw .mediaUnreadable(media.url)
        }
      }
    }
    guard !trackIDs.isEmpty else {
      return
    }
    try await Composition.runOn(lastSounds, past: timeline.duration)
    withExtendedLifetime(assets) { }
    let read = range ?? TimeRange(start: .zero, end: timeline.duration)
    framesRead = Int((read.start.seconds * Self.sampleRate).rounded())
    framesLeft = Int((read.duration.seconds * Self.sampleRate).rounded())
    limiter = SoundShaping(limiter: timeline.limiter, pan: 0)
    let mix = Composition.audioMix(
      for: timeline,
      trackIDs: trackIDs.mapValues { [$0] },
      shaping: .unshaped,
    )
    do {
      let reader = try AVAssetReader(asset: composition)
      // why: no end, so the run-on past the timeline still feeds the stretcher; framesLeft stops.
      reader.timeRange = CMTimeRange(start: read.start.cmTime, duration: .positiveInfinity)
      for track in timeline.tracks {
        guard
          let trackID = trackIDs[track.id],
          let audio = composition.track(withTrackID: trackID)
        else {
          continue
        }
        let output = AVAssetReaderAudioMixOutput(audioTracks: [audio], audioSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: Self.sampleRate,
          AVNumberOfChannelsKey: 2,
          AVLinearPCMBitDepthKey: 32,
          AVLinearPCMIsFloatKey: true,
          AVLinearPCMIsNonInterleaved: false,
          AVLinearPCMIsBigEndianKey: false,
        ])
        output.audioMix = mix
        output.audioTimePitchAlgorithm = Composition.timePitchAlgorithm
        reader.add(output)
        lanes.append(Lane(
          output: output,
          shaping: SoundShaping(limiter: [], pan: track.pan),
          stereo: stereo[track.id] ?? [],
        ))
      }
      guard reader.startReading() else {
        throw EngineError.renderFailed
      }
      self.reader = reader
    } catch {
      logger.error("mix.readFailed reason=reader")
      throw .renderFailed
    }
  }

}
