import AVFoundation
import ShadesCore
import ShadesEngine

/// Exports the timeline, or part of it, as a movie on a canvas: drawn by the same compositor
/// that plays it, from the original media, and encoded by the Mac's hardware encoder.
public enum MovieExporter {

  // MARK: Public

  /// Writes `range` of the project (default: all of it) to `url` (`.mp4` or `.mov`) on `canvas`,
  /// with cut-outs from `mattes`, optical flow from `flows` (footage blur), noise-reduced sound
  /// from `cleanSound` and stereo copies of mono sound from `stereoSound`. A file already at
  /// `url` goes to the Trash.
  @MainActor
  public static func export(
    _ project: Project,
    to url: URL,
    canvas: Canvas,
    range: TimeRange? = nil,
    codec: VideoCodec = .hevc,
    mattes: [Media.ID: URL] = [:],
    flows: [Media.ID: URL] = [:],
    cleanSound: [Media.ID: URL] = [:],
    stereoSound: [Media.ID: URL] = [:],
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(ExportError) {
    let timeline = project.timeline
    let range = range ?? TimeRange(start: .zero, end: timeline.duration)
    guard range.end > range.start, timeline.duration > .zero else {
      throw .nothingToExport("the timeline is empty")
    }
    let composition: Composition
    do {
      composition = try await Composition.forRendering(
        project,
        mattes: mattes,
        flows: flows,
        cleanSound: cleanSound,
        stereoSound: stereoSound,
        canvas: canvas == .picture ? nil : canvas.size(for: timeline.format),
      )
    } catch {
      throw .renderFailed(error)
    }
    guard let session = AVAssetExportSession(asset: composition.asset, presetName: codec.preset)
    else {
      logger.error("export.failed reason=session codec=\(codec.rawValue, privacy: .public)")
      throw .encodingFailed
    }
    // why: the file's colour tags come from these properties, not from the frames. With the
    // transfer left unset, AVFoundation keeps HDR's own and the layer shader tone-maps it.
    let video = composition.videoComposition.mutableCopy() as? AVMutableVideoComposition
    video?.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    video?.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    session.videoComposition = video
    session.audioMix = composition.audioMix(for: timeline)
    session.audioTimePitchAlgorithm = Composition.timePitchAlgorithm
    session.timeRange = CMTimeRange(start: range.start.cmTime, end: range.end.cmTime)
    try moveAside(url)
    let watcher = Task {
      for await state in session.states(updateInterval: 0.25) {
        if case .exporting(let exporting) = state {
          progress(exporting.fractionCompleted)
        }
      }
    }
    defer { watcher.cancel() }
    do {
      try await session.export(to: url, as: url.pathExtension == "mov" ? .mov : .mp4)
    } catch {
      guard !Task.isCancelled else {
        throw .cancelled
      }
      let code = (error as NSError).code
      logger.error("export.failed reason=encode code=\(code) path=\(url.path, privacy: .private)")
      throw .encodingFailed
    }
  }

  // MARK: Internal

  /// Moves a file already at `url` to the Trash, so the export can take its place.
  static func moveAside(_ url: URL) throws(ExportError) {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return
    }
    do {
      try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    } catch {
      logger.error("export.failed reason=occupied path=\(url.path, privacy: .private)")
      throw .unwritable(url)
    }
  }

}
