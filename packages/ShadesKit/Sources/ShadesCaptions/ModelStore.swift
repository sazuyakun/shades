import Foundation
import WhisperKit

// MARK: - ModelStore

/// Where speech models live on disk, and fetching them. Shades reads Nebula's models first (same
/// WhisperKit version and layout), so a model either app downloaded is never fetched twice.
public enum ModelStore {

  // MARK: Public

  /// Shades' own models folder.
  public static let shadesFolder = URL.applicationSupportDirectory
    .appending(path: "Shades/Models", directoryHint: .isDirectory)
  /// Nebula's models folder, checked first.
  public static let nebulaFolder = URL.applicationSupportDirectory
    .appending(path: "Nebula/Models", directoryHint: .isDirectory)

  /// Where a ready copy of `model` is, if one has been downloaded.
  public static func readyFolder(for model: TranscriptionModel) -> URL? {
    [nebulaFolder, shadesFolder].lazy.map { folder(for: model, in: $0) }.first(where: isReady)
  }

  /// Downloads `model` (and its tokenizer) into Shades' folder and returns where it is.
  @concurrent
  public static func download(
    _ model: TranscriptionModel,
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(CaptionsError) -> URL {
    let folder: URL
    do {
      try FileManager.default.createDirectory(at: shadesFolder, withIntermediateDirectories: true)
      folder = try await WhisperKit.download(
        variant: model.rawValue,
        downloadBase: shadesFolder,
        from: repository,
        progressCallback: { download in progress(min(max(download.fractionCompleted, 0), 1)) },
      )
      // why: fetching the tokenizer now lets later transcripts work offline.
      _ = try await ModelUtilities.loadTokenizer(for: model.variant, tokenizerFolder: shadesFolder)
      try Data().write(to: folder.appending(path: readyMarker))
    } catch {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      logger.error("model.downloadFailed model=\(model.rawValue, privacy: .public)")
      throw .modelDownloadFailed(model: model.title)
    }
    guard isReady(folder) else {
      logger
        .error("model.downloadFailed reason=incomplete model=\(model.rawValue, privacy: .public)")
      throw .modelDownloadFailed(model: model.title)
    }
    return folder
  }

  // MARK: Internal

  /// The repository models download from.
  static let repository = "argmaxinc/whisperkit-coreml"

  /// The folder a model's tokenizer lives under (its models folder).
  static func modelsFolder(containing folder: URL) -> URL {
    folder.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  // MARK: Private

  /// Written into a model folder once its download finished; Nebula writes the same file.
  private static let readyMarker = ".nebula-ready"
  private static let requiredBundles = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]

  private static func folder(for model: TranscriptionModel, in base: URL) -> URL {
    base.appending(path: "models/\(repository)/\(model.rawValue)", directoryHint: .isDirectory)
  }

  private static func isReady(_ folder: URL) -> Bool {
    let files = [readyMarker] + requiredBundles.map { "\($0).mlmodelc" }
    return files
      .allSatisfy { FileManager.default.fileExists(atPath: folder.appending(path: $0).path) }
  }

}

extension TranscriptionModel {
  /// WhisperKit's family for this model, to find its tokenizer.
  var variant: ModelVariant {
    switch self {
    case .base: .base
    case .small: .small
    case .largeTurbo: .largev3
    }
  }
}
