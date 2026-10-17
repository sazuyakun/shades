import ShadesCore

/// Changes the words of a text clip.
public struct SetText: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, text: String) {
    self.clipID = clipID
    self.text = text
  }

  // MARK: Public

  public static let title = "Change Text"
  public static let name = "set_text"
  public static let summary = "Change the words of a text clip (a caption or title)."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID, "text": JSONSchema.string("The new words")],
    required: ["clip_id", "text"],
  )

  public let clipID: Clip.ID
  public let text: String

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    guard
      case .text(var content) = project.timeline.tracks[location.track].clips[location.clip]
        .source
    else {
      throw rejected(.invalidValue("that clip isn't text"))
    }
    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw rejected(.invalidValue("the text is empty"))
    }
    content.text = text
    project.timeline.tracks[location.track].clips[location.clip].source = .text(content)
  }

}
