import ShadesCore

/// Adds hand-drawn lines over the picture as a clip on a free track above the footage.
public struct AddDrawing: ToolCommand {

  // MARK: Lifecycle

  public init(
    at time: MediaTime,
    duration: MediaTime? = nil,
    strokes: [[DrawingPoint]]? = nil,
    svgPath: String? = nil,
    viewBox: [Double]? = nil,
    color: HexColor? = nil,
    width: Double? = nil,
    glow: Double? = nil,
    boil: Double? = nil,
    writeOn: Double? = nil,
  ) {
    at = time
    self.duration = duration
    self.strokes = strokes
    self.svgPath = svgPath
    self.viewBox = viewBox
    self.color = color
    self.width = width
    self.glow = glow
    self.boil = boil
    self.writeOn = writeOn
  }

  // MARK: Public

  public static let title = "Add Drawing"
  public static let name = "add_drawing"
  public static let summary = "Draw lines over the picture (doodles, circles, arrows, underlines) "
    + "as a clip on a free track above, from points or SVG path data. They wobble like hand "
    + "animation (boil) and can draw themselves on (write_on), with an optional glow."
  public static let parameters = JSONSchema.object(
    [
      "at": Fields.time("When it appears"),
      "duration": JSONSchema.number("How long it stays, in seconds (default 3)", minimum: 0.04),
      "strokes": DrawingFields.strokes,
      "svg_path": DrawingFields.svgPath,
      "view_box": DrawingFields.viewBox,
    ].merging(DrawingFields.style) { $1 },
    required: ["at"],
  )

  public let at: MediaTime
  public let duration: MediaTime?
  public let strokes: [[DrawingPoint]]?
  public let svgPath: String?
  public let viewBox: [Double]?
  public let color: HexColor?
  public let width: Double?
  public let glow: Double?
  public let boil: Double?
  public let writeOn: Double?

  public func apply(to project: inout Project) throws(CommandError) {
    let lines = try drawnStrokes()
    guard !lines.isEmpty, lines.allSatisfy({ !$0.isEmpty }) else {
      throw rejected(.invalidValue("give strokes with points, or an svg_path"))
    }
    let drawing = try SetDrawing.styled(
      Drawing(strokes: lines),
      color: color,
      width: width,
      glow: glow,
      boil: boil,
      writeOn: writeOn,
    )
    let start = project.onFrame(at)
    let length = max(
      project.onFrame(duration ?? MediaTime(seconds: 3)),
      project.timeline.format.frameDuration,
    )
    let index = project.freeUpperTrack(.video, from: start, to: start + length)
    project.timeline.tracks[index].add(Clip(
      source: .drawing(drawing),
      sourceStart: .zero,
      duration: length,
      timelineStart: start,
    ))
  }

  // MARK: Private

  private func drawnStrokes() throws(CommandError) -> [[DrawingPoint]] {
    if let svgPath {
      let box = viewBox ?? [1, 1]
      guard box.count == 2, box[0] > 0, box[1] > 0 else {
        throw rejected(.invalidValue("view_box is [width, height], both above 0"))
      }
      return try SVGPath.strokes(from: svgPath, viewBox: (box[0], box[1]))
    }
    return strokes ?? []
  }

}
