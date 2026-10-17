import ShadesCore

/// Places a text clip (a caption or title) on a text track, drawn above the video.
public struct AddText: ToolCommand {

  // MARK: Lifecycle

  public init(text: String, at time: MediaTime, duration: MediaTime, track: String? = nil) {
    self.text = text
    at = time
    self.duration = duration
    self.track = track
  }

  // MARK: Public

  public static let title = "Add Text"
  public static let name = "add_text"
  public static let summary = "Place text on screen from a time for a duration, on a text track "
    + "(T1 by default, added if missing), replacing text already there."
  public static let parameters = JSONSchema.object(
    [
      "text": JSONSchema.string("The words to show"),
      "at": Fields.time("When it appears"),
      "duration": JSONSchema.number("How long it stays, in seconds", minimum: 0.04),
      "track": JSONSchema.string("A text track like T1 or T2"),
    ],
    required: ["text", "at", "duration"],
  )

  public let text: String
  public let at: MediaTime
  public let duration: MediaTime
  public let track: String?

  public func apply(to project: inout Project) throws(CommandError) {
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw rejected(.invalidValue("the text is empty"))
    }
    let index = try project.textTrack(labeled: track)
    let start = project.onFrame(at)
    let length = max(project.onFrame(duration), project.timeline.format.frameDuration)
    project.timeline.tracks[index].clear(from: start, to: start + length)
    project.timeline.tracks[index].add(Clip(
      source: .text(TextContent(text: text)),
      sourceStart: .zero,
      duration: length,
      timelineStart: start,
    ))
  }

}
