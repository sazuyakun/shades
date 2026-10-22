import AVFoundation
import ShadesCore

// MARK: - MixReader

/// Reads a project's finished sound mix (every track, with volumes, fades, ducking and the
/// master level) as stereo samples, a stretch at a time. Reading blocks while audio decodes, so
/// the reader runs on its own dispatch queue, never on Swift's thread pool.
public actor MixReader {

  // MARK: Lifecycle

  /// A reader for `project`'s mix, read from the original media (or `cleanSound`, the
  /// noise-reduced sound, for clips set to use it).
  public init(
    project: Project,
    cleanSound: [Media.ID: URL] = [:],
    stereoSound: [Media.ID: URL] = [:],
  ) {
    self.project = project
    self.cleanSound = cleanSound
    self.stereoSound = stereoSound
  }

  // MARK: Public

  /// Samples a second: what the mix is read at.
  public static let sampleRate = 48000.0

  nonisolated public var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  /// The next stretch of the mix as interleaved left/right samples, or `nil` at its end.
  public func nextChunk() async throws(EngineError) -> [Float]? {
    if output == nil {
      try await start()
    }
    guard framesLeft > 0, let output else {
      return nil
    }
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
    let frames = min(samples.count / 2, framesLeft)
    framesLeft -= frames
    return Array(samples.prefix(frames * 2))
  }

  // MARK: Private

  private nonisolated let queue = DispatchSerialQueue(label: "com.sazuyakun.shades.mix")
  private let project: Project
  private let cleanSound: [Media.ID: URL]
  private let stereoSound: [Media.ID: URL]
  private var reader: AVAssetReader?
  private var output: AVAssetReaderAudioMixOutput?
  /// How many more frames belong to the timeline; the run-on past its end isn't the mix.
  private var framesLeft = 0

  /// Lays every clip's sound out in a composition and starts reading it through the mix.
  private func start() async throws(EngineError) {
    let timeline = project.timeline
    let composition = AVMutableComposition()
    var trackIDs = [Track.ID: CMPersistentTrackID]()
    var lastSounds = [AVMutableCompositionTrack: AVAssetTrack]()
    for track in timeline.tracks where track.kind != .text {
      var target: AVMutableCompositionTrack?
      for clip in track.clips {
        guard
          let mediaID = clip.mediaID,
          let media = project.media(withID: mediaID), media.hasAudio, !clip.isFrozen
        else {
          continue
        }
        // why: a track doesn't keep its asset alive, and can't be inserted once the asset is gone.
        let asset = AVURLAsset(
          url: Composition.sound(of: clip, cleanSound: cleanSound, stereoSound: stereoSound)
            ?? media.url
        )
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
          if Composition.runsOn(clip, in: timeline) {
            lastSounds[destination] = audio
          }
          withExtendedLifetime(asset) { }
        } catch {
          let code = (error as NSError).code
          let path = media.url.path
          logger.error("mix.readFailed reason=insert code=\(code) path=\(path, privacy: .private)")
          throw .mediaUnreadable(media.url)
        }
      }
    }
    let tracks = composition.tracks(withMediaType: .audio)
    guard !tracks.isEmpty else {
      return
    }
    Composition.runOn(lastSounds, past: timeline.duration)
    framesLeft = Int((timeline.duration.seconds * Self.sampleRate).rounded())
    do {
      let reader = try AVAssetReader(asset: composition)
      let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: Self.sampleRate,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
        AVLinearPCMIsBigEndianKey: false,
      ])
      output.audioMix = Composition.audioMix(for: timeline, trackIDs: trackIDs)
      output.audioTimePitchAlgorithm = Composition.timePitchAlgorithm
      reader.add(output)
      guard reader.startReading() else {
        throw EngineError.renderFailed
      }
      self.reader = reader
      self.output = output
    } catch {
      logger.error("mix.readFailed reason=reader")
      throw .renderFailed
    }
  }

}
