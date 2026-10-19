import Foundation
import ShadesCore

/// Writes one file of an export request, whatever its kind.
public enum Exporter {
  /// Writes `output` of `request` from `project`: with cut-outs from `mattes`, noise-reduced
  /// sound from `cleanSound`, and captions from `transcripts` when there are none on the
  /// timeline.
  @MainActor
  public static func write(
    _ output: ExportOutput,
    of request: ExportRequest,
    project: Project,
    mattes: [Media.ID: URL],
    cleanSound: [Media.ID: URL],
    transcripts: [Media.ID: Transcript],
    progress: @escaping @Sendable (Double) -> Void,
  ) async throws(ExportError) {
    switch request.kind {
    case .youtube,
         .shorts:
      try await MovieExporter.export(
        project,
        to: output.url,
        canvas: request.kind == .youtube ? .youtube : .vertical,
        range: output.range,
        codec: request.codec,
        mattes: mattes,
        cleanSound: cleanSound,
        progress: progress,
      )

    case .frame:
      try await StillExporter.frame(
        of: project,
        atSeconds: output.range.start.seconds,
        to: output.url,
        mattes: mattes,
      )

    case .gif:
      try await StillExporter.gif(
        of: project,
        range: output.range,
        to: output.url,
        mattes: mattes,
        progress: progress,
      )

    case .srt:
      let srt = try Subtitles.srt(of: project.timeline, transcripts: transcripts)
      try MovieExporter.moveAside(output.url)
      do {
        try srt.write(to: output.url, atomically: true, encoding: .utf8)
      } catch {
        logger.error("srt.failed reason=write path=\(output.url.path, privacy: .private)")
        throw .unwritable(output.url)
      }
    }
  }
}
