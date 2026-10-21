/// Argument schemas for drawing tools, shared by `add_drawing` and `set_drawing`.
enum DrawingFields {
  static let strokes = JSONSchema.array(
    "Lines to draw: each a list of [x, y] points, as fractions of the frame from its top left",
    items: JSONSchema.array("A stroke", items: JSONSchema.array(
      "A point: [x, y]",
      items: JSONSchema.number("0 to 1"),
    )),
  )
  static let svgPath = JSONSchema.string(
    "Lines as SVG path data (M L H V C Q Z), instead of strokes; scaled from view_box to the frame"
  )
  static let viewBox = JSONSchema.array(
    "The SVG path's width and height, mapped onto the whole frame (default [1, 1])",
    items: JSONSchema.number("A size"),
  )
  static let style = [
    "color": JSONSchema.string("Line colour like #FFFFFF"),
    "width": JSONSchema.number("Thickness as a fraction of the frame height (default 0.006)"),
    "glow": JSONSchema.number("Glow, 0 (none) to 1", minimum: 0, maximum: 1),
    "boil": JSONSchema.number(
      "Wobbles a second, like hand animation (default 12; 0 holds it still)",
      minimum: 0,
      maximum: 30,
    ),
    "write_on": JSONSchema.number(
      "Seconds the lines take to draw themselves on (default 0: all at once)",
      minimum: 0,
    ),
    "erase_off": JSONSchema.number(
      "Seconds the lines take to undraw at the clip's end, last stroke first (default 0: they stay)",
      minimum: 0,
    ),
  ]
}
