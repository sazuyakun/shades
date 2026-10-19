import Foundation

/// Where the stem separation model lives, and fetching it the first time it's needed. It's
/// HTDemucs (Meta, MIT) converted to CoreML: about 100 MB, never bundled with Shades.
public enum StemModel {

  // MARK: Public

  /// The compiled model in Shades' models folder.
  public static let url = URL.applicationSupportDirectory
    .appending(path: "Shades/Models/HTDemucs.mlmodelc", directoryHint: .isDirectory)

  /// Whether the model has been downloaded.
  public static var isReady: Bool {
    FileManager.default.fileExists(atPath: url.appending(path: "model.mil").path)
  }

  /// Downloads and unpacks the model into Shades' models folder.
  @concurrent
  public static func download() async throws(AudioError) {
    guard let source = URL(string: source) else {
      logger.fault("stems.badSource")
      assertionFailure("the model's address is a valid URL")
      throw .modelDownloadFailed
    }
    let archive: URL
    do {
      (archive, _) = try await URLSession.shared.download(from: source)
    } catch {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      logger.error("stems.downloadFailed reason=network")
      throw .modelDownloadFailed
    }
    let folder = url.deletingLastPathComponent()
    let status = await withCheckedContinuation { continuation in
      queue.async { continuation.resume(returning: unpack(archive, into: folder)) }
    }
    guard status == 0, isReady else {
      logger.error("stems.downloadFailed reason=unpack status=\(status, privacy: .public)")
      throw .modelDownloadFailed
    }
  }

  // MARK: Private

  private static let source =
    "https://github.com/sazuyakun/shades/releases/download/models-1/HTDemucs.mlmodelc.zip"
  private static let queue = DispatchQueue(label: "com.sazuyakun.shades.stem-model")

  /// Unzips `archive` into `folder` with `ditto`, and returns its exit status. Blocks.
  private static func unpack(_ archive: URL, into folder: URL) -> Int32 {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", archive.path, folder.path]
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try process.run()
    } catch {
      return -1
    }
    process.waitUntilExit()
    return process.terminationStatus
  }

}
