import Foundation
import ShadesCaptions
import ShadesCore

/// Captions as a SubRip (`.srt`) file, for YouTube and other players to show.
public enum Subtitles {

  // MARK: Public

  /// The timeline's captions as SRT: the caption clips on it (text clips made from what's said),
  /// or, with none, caption lines made from the transcripts of what's heard.
  public static func srt(
    of timeline: Timeline,
    transcripts: [Media.ID: Transcript],
  ) throws(ExportError) -> String {
    let captions = timeline.tracks.filter { $0.kind == .text && !$0.isHidden }.flatMap(\.clips)
      .filter { $0.text?.words?.isEmpty == false }
      .sorted { $0.timelineStart < $1.timelineStart }
      .compactMap { clip in
        clip.text.map { ($0.text, clip.timelineStart, clip.timelineEnd) }
      }
    let lines = captions.isEmpty
      ? CaptionLayout.lines(for: timeline.spokenWords(transcripts: transcripts))
        .map { ($0.text, $0.start, $0.end) }
      : captions
    guard !lines.isEmpty else {
      throw .nothingToExport("there are no captions and nothing on the timeline is transcribed")
    }
    return lines.enumerated().lazy.map { index, line in
      "\(index + 1)\n\(timestamp(line.1)) --> \(timestamp(line.2))\n\(line.0)\n"
    }.joined(separator: "\n")
  }

  // MARK: Private

  /// `time` as SRT writes it: `00:01:02,345`.
  private static func timestamp(_ time: MediaTime) -> String {
    let milliseconds = Int((time.seconds * 1000).rounded())
    return String(
      format: "%02d:%02d:%02d,%03d",
      milliseconds / 3_600_000,
      milliseconds / 60000 % 60,
      milliseconds / 1000 % 60,
      milliseconds % 1000,
    )
  }

}
