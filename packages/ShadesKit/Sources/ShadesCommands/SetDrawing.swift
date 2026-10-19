import ShadesCore

/// Changes a drawing's lines or look. Fields left out stay as they are.
public struct SetDrawing: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    strokes: [[DrawingPoint]]? = nil,
    addStrokes: [[DrawingPoint]]? = nil,
    color: HexColor? = nil,
    width: Double? = nil,
    glow: Double? = nil,
    boil: Double? = nil,
    writeOn: Double? = nil,
  ) {
    self.clipID = clipID
    self.strokes = strokes
    self.addStrokes = addStrokes
    self.color = color
    self.width = width
    self.glow = glow
    self.boil = boil
    self.writeOn = writeOn
  }

  // MARK: Public

  public static let title = "Change Drawing"
  public static let name = "set_drawing"
  public static let summary = "Change a drawing's lines (replace them, or add strokes) or its "
    + "look: colour, width, glow, boil and write_on. Leave out what shouldn't change."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "strokes": DrawingFields.strokes,
      "add_strokes": DrawingFields.strokes,
    ].merging(DrawingFields.style) { $1 },
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let strokes: [[DrawingPoint]]?
  public let addStrokes: [[DrawingPoint]]?
  public let color: HexColor?
  public let width: Double?
  public let glow: Double?
  public let boil: Double?
  public let writeOn: Double?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    guard var drawing = project.timeline.tracks[location.track].clips[location.clip].drawing else {
      throw rejected(.invalidValue("that clip isn't a drawing"))
    }
    drawing.strokes = (strokes ?? drawing.strokes) + (addStrokes ?? [])
    drawing = try Self.styled(
      drawing,
      color: color,
      width: width,
      glow: glow,
      boil: boil,
      writeOn: writeOn,
    )
    project.timeline.tracks[location.track].clips[location.clip].source = .drawing(drawing)
  }

  // MARK: Internal

  /// `drawing` with the given style changes, checked.
  static func styled(
    _ drawing: Drawing,
    color: HexColor?,
    width: Double?,
    glow: Double?,
    boil: Double?,
    writeOn: Double?,
  ) throws(CommandError) -> Drawing {
    if let width, !(0.0005 ... 0.1).contains(width) {
      throw rejected(.invalidValue("drawing width goes from 0.0005 to 0.1 of the frame height"))
    }
    if let glow, !(0 ... 1).contains(glow) {
      throw rejected(.invalidValue("glow goes from 0 to 1"))
    }
    if let boil, !(0 ... 30).contains(boil) {
      throw rejected(.invalidValue("boil goes from 0 to 30 wobbles a second"))
    }
    if let writeOn, writeOn < 0 {
      throw rejected(.invalidValue("write_on can't be negative"))
    }
    var styled = drawing
    styled.color = color ?? drawing.color
    styled.width = width ?? drawing.width
    styled.glow = glow ?? drawing.glow
    styled.boil = boil ?? drawing.boil
    styled.writeOn = writeOn ?? drawing.writeOn
    return styled
  }

}
