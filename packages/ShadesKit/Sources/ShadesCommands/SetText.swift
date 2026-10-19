import ShadesCore

/// Changes a text clip's words, look or how its words come on.
public struct SetText: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    text: String? = nil,
    style: TextStyle? = nil,
    reveal: TextReveal? = nil,
  ) {
    self.clipID = clipID
    self.text = text
    self.style = style
    self.reveal = reveal
  }

  // MARK: Public

  public static let title = "Change Text"
  public static let name = "set_text"
  public static let summary = "Change a text clip's words, look or reveal. A style replaces the "
    + "whole look (fields left out take the caption look). Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "text": JSONSchema.string("The new words"),
      "style": Fields.textStyle,
      "reveal": Fields.reveal,
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let text: String?
  public let style: TextStyle?
  public let reveal: TextReveal?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    guard
      case .text(var content) = project.timeline.tracks[location.track].clips[location.clip]
        .source
    else {
      throw rejected(.invalidValue("that clip isn't text"))
    }
    if let text, text.trimmingCharacters(in: .whitespaces).isEmpty {
      throw rejected(.invalidValue("the text is empty"))
    }
    try style?.validate()
    content.text = text ?? content.text
    content.style = style ?? content.style
    content.reveal = reveal ?? content.reveal
    project.timeline.tracks[location.track].clips[location.clip].source = .text(content)
  }

}
