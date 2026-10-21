import ShadesCore

/// Adds caption lines as text clips, all on one text track that's free for every line (added if
/// none is), styled and revealed alike.
public struct AddCaptions: Command {

  // MARK: Lifecycle

  public init(lines: [Line], style: TextStyle?, reveal: TextReveal) {
    self.lines = lines
    self.style = style
    self.reveal = reveal
  }

  // MARK: Public

  /// One caption: its words and when they're said, on the timeline.
  public struct Line: Sendable {
    public init(text: String, start: MediaTime, end: MediaTime, words: [TimedWord]) {
      self.text = text
      self.start = start
      self.end = end
      self.words = words
    }

    public let text: String
    public let start: MediaTime
    public let end: MediaTime
    /// When each word is said, in seconds from the line's start.
    public let words: [TimedWord]
  }

  public static let title = "Add Captions"

  public let lines: [Line]
  public let style: TextStyle?
  public let reveal: TextReveal

  public func apply(to project: inout Project) throws(CommandError) {
    let free = project.timeline.tracks.firstIndex { track in
      track.kind == .text && lines.allSatisfy { track.isClear(from: $0.start, to: $0.end) }
    }
    let index = free ?? project.addTrack(.text)
    let label = project.timeline.label(of: project.timeline.tracks[index])
    for line in lines {
      let count = line.text.split(separator: " ", omittingEmptySubsequences: true).count
      try AddText(
        text: line.text,
        at: line.start,
        duration: line.end - line.start,
        track: label,
        style: style,
        reveal: reveal,
        // why: timings that don't pair up with the text's words can't time them, so the
        // reveal spreads the words instead.
        words: line.words.count == count ? line.words : nil,
      ).apply(to: &project)
    }
  }

}
