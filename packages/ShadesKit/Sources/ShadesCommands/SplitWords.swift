import ShadesCore

/// Splits a text clip into one clip per word, each on its own text track and still drawn where
/// it sat in the line, so every word can be placed, animated and layered on its own.
public struct SplitWords: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID) {
    self.clipID = clipID
  }

  // MARK: Public

  public static let title = "Split into Words"
  public static let name = "split_words"
  public static let summary = "Split a text or caption clip into one text clip per word (per-word "
    + "layers), each on its own text track (added as needed) and still drawn where it sat in the "
    + "line, with the same look, reveal, word timings and timing. Then set_clip, set_keyframes "
    + "and depth_slot move, animate and layer each word on its own; get_project lists them."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    guard let content = clip.text, content.word == nil else {
      throw rejected(.invalidValue("split_words takes a whole text clip"))
    }
    let count = content.wordList.count
    guard count > 1 else {
      throw rejected(.invalidValue("the text has only one word"))
    }
    project.timeline.tracks[location.track].clips[location.clip].source = .text(word(
      0,
      of: content,
    ))
    for index in 1 ..< count {
      var copy = clip.withNewID()
      copy.source = .text(word(index, of: content))
      let track = project.freeTrack(.text, from: clip.timelineStart, to: clip.timelineEnd)
      project.timeline.tracks[track].add(copy)
    }
  }

  // MARK: Private

  private func word(_ index: Int, of content: TextContent) -> TextContent {
    var word = content
    word.word = index
    return word
  }

}
