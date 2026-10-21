import ShadesCore

/// Places a text clip (a caption or title) on a text track, drawn above the video.
public struct AddText: ToolCommand {

  // MARK: Lifecycle

  public init(
    text: String,
    at time: MediaTime,
    duration: MediaTime,
    track: String? = nil,
    style: TextStyle? = nil,
    reveal: TextReveal? = nil,
    words: [TimedWord]? = nil,
  ) {
    self.text = text
    at = time
    self.duration = duration
    self.track = track
    self.style = style
    self.reveal = reveal
    self.words = words
  }

  // MARK: Public

  public static let title = "Add Text"
  public static let name = "add_text"
  public static let summary = "Place text on screen from a time for a duration: on the named "
    + "text track (replacing text already there), or by default on the first text track free "
    + "then (added if none is). Give a style for titles (anchor center) and a reveal for kinetic "
    + "type."
  public static let parameters = JSONSchema.object(
    [
      "text": JSONSchema.string("The words to show"),
      "at": Fields.time("When it appears"),
      "duration": JSONSchema.number("How long it stays, in seconds", minimum: 0.04),
      "track": JSONSchema.string("A text track like T1 or T2"),
      "style": Fields.textStyle,
      "reveal": Fields.reveal,
    ],
    required: ["text", "at", "duration"],
  )

  public let text: String
  public let at: MediaTime
  public let duration: MediaTime
  public let track: String?
  public let style: TextStyle?
  public let reveal: TextReveal?
  /// When each word is said, in seconds from the clip's start (captions pass these).
  public let words: [TimedWord]?

  public func apply(to project: inout Project) throws(CommandError) {
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw rejected(.invalidValue("the text is empty"))
    }
    try style?.validate()
    let start = project.onFrame(at)
    let length = max(project.onFrame(duration), project.timeline.format.frameDuration)
    let index: Int
    if let track {
      index = try project.textTrack(labeled: track)
      project.timeline.tracks[index].clear(from: start, to: start + length)
    } else {
      index = project.freeTrack(.text, from: start, to: start + length)
    }
    project.timeline.tracks[index].add(Clip(
      source: .text(TextContent(
        text: text,
        style: style ?? .caption,
        words: words,
        reveal: reveal ?? .none,
      )),
      sourceStart: .zero,
      duration: length,
      timelineStart: start,
    ))
  }

}
