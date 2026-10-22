import Foundation
import ShadesCore
import ShadesMedia
import WhisperKit

/// Transcribes what's said in a media file on this Mac, with word timings. Ported from Nebula:
/// every WhisperKit object is made and used inside one call, so nothing unsafe crosses threads.
public enum Transcriber {

  // MARK: Public

  /// Transcribes `url` with `model` (downloading it first if needed). `language` is a code like
  /// "en" or "hi"; `nil` detects it. `progress` goes from 0 to 1 over download and transcription.
  @concurrent
  public static func transcribe(
    _ url: URL,
    model: TranscriptionModel,
    language: String? = nil,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(CaptionsError) -> Transcript {
    let folder: URL =
      if let ready = ModelStore.readyFolder(for: model) {
        ready
      } else {
        try await ModelStore.download(model) { progress($0 * 0.3) }
      }
    await JobQueue.pausePoint()
    let samples: [Float]
    do {
      samples = try await AudioDecoder.mono(from: url, sampleRate: sampleRate)
    } catch {
      throw error == .noAudio(url) ? .noAudio(url) : .audioUnreadable(error)
    }
    // why: less than half a second of sound can't hold a word.
    guard samples.count >= Int(sampleRate / 2) else {
      logger.error("transcribe.failed reason=tooShort")
      throw .noSpeech
    }
    let segments = try await recognize(samples, model: model, folder: folder, language: language) {
      progress(0.3 + $0 * 0.7)
    }
    guard !segments.segments.isEmpty else {
      logger.error("transcribe.failed reason=noSpeech")
      throw .noSpeech
    }
    progress(1)
    return segments
  }

  // MARK: Internal

  /// Samples per second the speech model listens to.
  static let sampleRate = 16_000.0

  // MARK: Private

  private static func recognize(
    _ samples: [Float],
    model: TranscriptionModel,
    folder: URL,
    language: String?,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(CaptionsError) -> Transcript {
    let modelsFolder = ModelStore.modelsFolder(containing: folder)
    let recognizer: WhisperKit
    do {
      recognizer = try await WhisperKit(WhisperKitConfig(
        model: model.rawValue,
        downloadBase: modelsFolder,
        modelRepo: ModelStore.repository,
        modelFolder: folder.path,
        tokenizerFolder: modelsFolder,
        verbose: false,
        logLevel: .none,
        prewarm: false,
        load: true,
        download: false,
      ))
    } catch {
      logger.error("model.loadFailed model=\(model.rawValue, privacy: .public)")
      throw .modelLoadFailed(model: model.title)
    }
    let options = DecodingOptions(
      verbose: false,
      task: .transcribe,
      language: language,
      usePrefillPrompt: language != nil,
      detectLanguage: language == nil,
      skipSpecialTokens: true,
      withoutTimestamps: false,
      wordTimestamps: true,
      chunkingStrategy: .vad,
    )
    let tracker = recognizer.progress
    let poller = Task {
      while !Task.isCancelled {
        progress(min(tracker.fractionCompleted, 0.99))
        try? await Task.sleep(for: .milliseconds(250)) // why: cancelled ends the polling.
      }
    }
    defer { poller.cancel() }
    let results: [TranscriptionResult]
    do {
      results = try await recognizer.transcribe(audioArray: samples, decodeOptions: options)
    } catch {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      logger.error("transcribe.failed reason=recognizer")
      throw .transcriptionFailed
    }
    let segments = results.flatMap(\.segments)
      .map { segment in
        RecognizedSegment(
          text: segment.text,
          start: Double(segment.start),
          end: Double(segment.end),
          words: (segment.words ?? []).map { .init(
            text: $0.word,
            start: Double($0.start),
            end: Double($0.end),
          ) },
        )
      }
      .sorted { $0.start < $1.start }
      .compactMap(\.cleaned)
    let detected = results.first.map(\.language).flatMap { $0.isEmpty ? nil : $0 }
    return Transcript(segments: segments, language: language ?? detected)
  }

}
