import ShadesCore

/// Changes a text clip's words, look, how its words come on, or the path it follows.
public struct SetText: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    text: String? = nil,
    style: TextStyle? = nil,
    reveal: TextReveal? = nil,
    path: [DrawingPoint]? = nil,
    svgPath: String? = nil,
    viewBox: [Double]? = nil,
    pathOffset: Double? = nil,
  ) {
    self.clipID = clipID
    self.text = text
    self.style = style
    self.reveal = reveal
    self.path = path
    self.svgPath = svgPath
    self.viewBox = viewBox
    self.pathOffset = pathOffset
  }

  // MARK: Public

  public static let title = "Change Text"
  public static let name = "set_text"
  public static let summary = "Change a text clip's words, look or reveal, or lay it along a "
    + "path (points or SVG path data): the letters stand on the path and turn with it, placed "
    + "at its start, middle or end by the style's align, moved along by path_offset (keyframe "
    + "pathOffset to make the text travel; a path ending where it starts is a loop). An empty "
    + "path puts the text back in lines. A style replaces the whole look (fields left out take "
    + "the caption look). Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "text": JSONSchema.string("The new words"),
      "style": Fields.textStyle,
      "reveal": Fields.reveal,
      "path": JSONSchema.array(
        "Points the text follows, [x, y] as fractions of the frame from its top left; [] for "
          + "none",
        items: JSONSchema.array("A point: [x, y]", items: JSONSchema.number("0 to 1")),
      ),
      "svg_path": JSONSchema.string(
        "The path as SVG path data (M L H V C Q Z) instead of points, scaled from view_box to "
          + "the frame"
      ),
      "view_box": DrawingFields.viewBox,
      "path_offset": JSONSchema.number(
        "Moves the text along its path, as a fraction of the path's length (default 0)"
      ),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let text: String?
  public let style: TextStyle?
  public let reveal: TextReveal?
  public let path: [DrawingPoint]?
  public let svgPath: String?
  public let viewBox: [Double]?
  public let pathOffset: Double?

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
    if let points = try newPath() {
      content.path = points.isEmpty
        ? nil
        : TextPath(points: points, offset: content.path?.offset ?? 0)
    }
    if let pathOffset {
      guard content.path != nil else {
        throw rejected(.invalidValue("path_offset needs a path; give path or svg_path"))
      }
      content.path?.offset = pathOffset
    }
    project.timeline.tracks[location.track].clips[location.clip].source = .text(content)
  }

  // MARK: Private

  /// The path given as points or SVG data (its pieces joined), or `nil` when neither is.
  private func newPath() throws(CommandError) -> [DrawingPoint]? {
    if let svgPath {
      let size = viewBox ?? [1, 1]
      guard size.count == 2, size.allSatisfy({ $0 > 0 }) else {
        throw rejected(.invalidValue("view_box is [width, height], both above 0"))
      }
      return try SVGPath.strokes(from: svgPath, viewBox: (size[0], size[1])).flatMap(\.self)
    }
    guard let path else {
      return nil
    }
    guard path.isEmpty || path.count > 1 else {
      throw rejected(.invalidValue("a path needs at least two points"))
    }
    return path
  }

}
