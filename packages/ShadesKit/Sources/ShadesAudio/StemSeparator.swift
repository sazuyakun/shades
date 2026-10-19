import CoreML
import Foundation
import ShadesMedia

/// Splits a recording into voice and music with HTDemucs (Meta, MIT), converted to CoreML. The
/// network runs on the GPU; the STFT around it is ours. Prediction blocks, so the separator runs
/// on its own dispatch queue, never on Swift's thread pool.
public actor StemSeparator {

  // MARK: Lifecycle

  private init(model: MLModel, spectrogram: StemSpectrogram) {
    self.model = model
    self.spectrogram = spectrogram
  }

  // MARK: Public

  /// The rate the model works at.
  public static let sampleRate = 44100.0

  nonisolated public var unownedExecutor: UnownedSerialExecutor {
    queue.asUnownedSerialExecutor()
  }

  /// The voice and music of the file at `url`, each as left and right samples at `sampleRate`,
  /// read with the compiled model at `modelURL`.
  @concurrent
  public static func separate(
    _ url: URL,
    modelURL: URL,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(AudioError) -> [Stem: [[Float]]] {
    let input: (left: [Float], right: [Float])
    do {
      input = try await AudioDecoder.stereo(from: url, sampleRate: sampleRate)
    } catch {
      throw .unreadable(error)
    }
    let separator = try await load(modelURL)
    let length = input.left.count
    let starts = Array(stride(from: 0, to: max(length, 1), by: step))
    var sums = Stem.allCases.reduce(into: [Stem: [[Float]]]()) { sums, stem in
      sums[stem] = [[Float]](repeating: [Float](repeating: 0, count: length), count: 2)
    }
    var weights = [Float](repeating: 0, count: length)
    for (index, start) in starts.enumerated() {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      let end = min(start + segment, length)
      let chunk = [input.left, input.right].map { channel in
        Array(channel[start ..< end]) + [Float](repeating: 0, count: segment - (end - start))
      }
      let stems = try await separator.separate(left: chunk[0], right: chunk[1])
      for offset in 0 ..< end - start {
        let weight = fade[offset]
        weights[start + offset] += weight
        for (stem, channels) in stems {
          sums[stem]?[0][start + offset] += channels[0][offset] * weight
          sums[stem]?[1][start + offset] += channels[1][offset] * weight
        }
      }
      progress(Double(index + 1) / Double(starts.count))
    }
    return sums.mapValues { channels in
      channels.map { channel in zip(channel, weights).map { $0 / max($1, 1e-6) } }
    }
  }

  // MARK: Private

  /// Samples the model reads at once: its training length, 7.8 s.
  private static let segment = 343_980
  /// How far apart segments start: they overlap by a quarter.
  private static let step = segment * 3 / 4
  /// How much each sample of a segment counts where segments overlap: rising to the middle and
  /// falling after, as Demucs blends them.
  private static let fade: [Float] = {
    let half = segment / 2
    let ramp = (1 ... half).map(Float.init) + (1 ... segment - half).reversed().map(Float.init)
    return ramp.map { $0 / Float(half) }
  }()

  /// The model's sources, in its output order.
  private static let sources = ["drums", "bass", "other", "vocals"]

  private nonisolated let queue = DispatchSerialQueue(label: "com.sazuyakun.shades.stems")
  private let model: MLModel
  private let spectrogram: StemSpectrogram

  /// Loads the compiled model for the GPU. The Neural Engine is left out: compiling this network
  /// for it can take hours.
  private static func load(_ url: URL) async throws(AudioError) -> StemSeparator {
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .cpuAndGPU
    guard let spectrogram = StemSpectrogram() else {
      logger.fault("stems.fftUnavailable")
      assertionFailure("a 4096-point FFT always sets up")
      throw .modelUnavailable
    }
    do {
      let model = try await MLModel.load(contentsOf: url, configuration: configuration)
      return StemSeparator(model: model, spectrogram: spectrogram)
    } catch {
      logger.error("stems.loadFailed path=\(url.path, privacy: .private)")
      throw .modelUnavailable
    }
  }

  /// One segment's voice and music, each as left and right samples.
  private func separate(left: [Float], right: [Float]) throws(AudioError) -> [Stem: [[Float]]] {
    let length = Self.segment
    let frames = StemSpectrogram.frames(for: length)
    let plane = StemSpectrogram.bins * frames
    let spectra = [left, right].map(spectrogram.forward)
    let outputs: MLFeatureProvider
    do {
      let mix = try MLMultiArray(shape: [1, 2, length as NSNumber], dataType: .float32)
      let spectrum = try MLMultiArray(
        shape: [1, 4, StemSpectrogram.bins as NSNumber, frames as NSNumber],
        dataType: .float32,
      )
      mix.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
        _ = buffer.update(fromContentsOf: left + right)
      }
      spectrum.withUnsafeMutableBufferPointer(ofType: Float.self) { buffer, _ in
        _ = buffer.update(fromContentsOf: spectra.flatMap { [$0.real, $0.imag] }.joined())
      }
      outputs = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: [
        "mix": mix,
        "spectrogram": spectrum,
      ]))
    } catch {
      logger.error("stems.predictionFailed")
      throw .separationFailed
    }
    guard
      let spectrumOut = outputs.featureValue(for: "spectrogram_out")?.multiArrayValue,
      let waveformOut = outputs.featureValue(for: "waveform_out")?.multiArrayValue
    else {
      logger.error("stems.predictionFailed reason=missingOutput")
      throw .separationFailed
    }
    let spectrumValues = MLShapedArray<Float>(converting: spectrumOut).scalars
    let waveformValues = MLShapedArray<Float>(converting: waveformOut).scalars
    let voice = Self.sources.firstIndex(of: "vocals") ?? 3
    return Stem.allCases.reduce(into: [Stem: [[Float]]]()) { stems, stem in
      let picked = stem == .voice ? [voice] : Self.sources.indices.filter { $0 != voice }
      stems[stem] = (0 ..< 2).map { channel in
        var real = [Float](repeating: 0, count: plane)
        var imag = real
        var wave = [Float](repeating: 0, count: length)
        for source in picked {
          let base = (source * 4 + channel * 2) * plane
          let waveBase = (source * 2 + channel) * length
          for index in 0 ..< plane {
            real[index] += spectrumValues[base + index]
            imag[index] += spectrumValues[base + plane + index]
          }
          for index in 0 ..< length {
            wave[index] += waveformValues[waveBase + index]
          }
        }
        let fromSpectrum = spectrogram.inverse(real: real, imag: imag, length: length)
        return zip(fromSpectrum, wave).map(+)
      }
    }
  }

}
