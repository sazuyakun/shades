import Foundation
import ShadesCore

// MARK: - ExportRequest

/// What to export, and where: the files it makes are named after `name` in `folder`.
public struct ExportRequest: Sendable {

  // MARK: Lifecycle

  public init(
    kind: ExportKind,
    folder: URL,
    name: String,
    codec: VideoCodec = .hevc,
    time: MediaTime = .zero,
    range: TimeRange? = nil,
  ) {
    self.kind = kind
    self.folder = folder
    self.name = name
    self.codec = codec
    self.time = time
    self.range = range
  }

  // MARK: Public

  public let kind: ExportKind
  public let folder: URL
  public let name: String
  public let codec: VideoCodec
  /// The moment a frame is taken from.
  public let time: MediaTime
  /// The stretch a GIF or YouTube video is made of; all of the timeline when `nil`.
  public let range: TimeRange?

  /// The files this request writes for `timeline`, each with the stretch it covers: one per
  /// short (or one of everything, when none are marked), otherwise one.
  public func outputs(for timeline: Timeline) -> [ExportOutput] {
    let whole = range ?? TimeRange(start: .zero, end: timeline.duration)
    switch kind {
    case .youtube:
      return [ExportOutput(url: file(name, "mp4"), range: whole)]

    case .shorts:
      guard !timeline.shorts.isEmpty else {
        return [ExportOutput(url: file(name, "mp4"), range: whole)]
      }
      return timeline.shorts.map { short in
        ExportOutput(url: file("\(name) - \(short.name)", "mp4"), range: short.range)
      }

    case .frame:
      return [ExportOutput(url: file(name, "png"), range: TimeRange(start: time, end: time))]

    case .gif:
      return [ExportOutput(url: file(name, "gif"), range: whole)]

    case .srt:
      return [ExportOutput(url: file(name, "srt"), range: whole)]
    }
  }

  // MARK: Private

  /// A file in the folder, its name made safe for the Finder.
  private func file(_ base: String, _ fileExtension: String) -> URL {
    let safe = base.replacing("/", with: "-").replacing(":", with: "-")
    return folder.appending(path: "\(safe).\(fileExtension)")
  }

}

// MARK: - ExportKind

/// The kinds of export.
public enum ExportKind: String, CaseIterable, Codable, Sendable {
  /// The picture on the 16:9 canvas.
  case youtube
  /// Each short (or the whole timeline) on the 9:16 canvas.
  case shorts
  /// One frame as a PNG.
  case frame
  /// A short looping GIF.
  case gif
  /// Captions as an SRT file.
  case srt
}

// MARK: - ExportOutput

/// One file an export writes, and the stretch of the timeline it covers.
public struct ExportOutput: Sendable, Equatable {
  public let url: URL
  public let range: TimeRange
}
