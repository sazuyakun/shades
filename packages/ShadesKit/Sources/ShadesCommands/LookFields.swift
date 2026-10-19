/// Argument schemas for grades and effects, shared by `set_look` and `add_adjustment`.
enum LookFields {
  static let grade = JSONSchema.object([
    "exposure": JSONSchema.number("Brightness in stops (+1 twice as bright), default 0"),
    "contrast": JSONSchema.number("1 unchanged; higher pushes darks and lights apart"),
    "saturation": JSONSchema.number("0 black and white, 1 unchanged, 2 twice as colourful"),
    "temperature": JSONSchema.number("-1 cool to 1 warm, default 0"),
    "tint": JSONSchema.number("-1 green to 1 magenta, default 0"),
    "lift": JSONSchema.number("Raise (positive) or crush the shadows, default 0"),
    "gamma": JSONSchema.number("Above 1 brightens the midtones, default 1"),
    "gain": JSONSchema.number("Scales the highlights, default 1"),
    "curves": JSONSchema.object([
      "master": JSONSchema.array("[input, output] points 0–1", items: JSONSchema.array(
        "A point",
        items: JSONSchema.number("0 to 1"),
      ))
    ]),
    "lut": JSONSchema.string("A .cube LUT: a file path, or a plugin's LUT by name"),
    "lut_amount": JSONSchema.number("How much of the LUT shows, 0 to 1", minimum: 0, maximum: 1),
  ])
  static let effects = JSONSchema.object([
    "grain": JSONSchema.number("Film grain, 0 to 1", minimum: 0, maximum: 1),
    "vignette": JSONSchema.number("Darkened corners, 0 to 1", minimum: 0, maximum: 1),
    "halation": JSONSchema.number("Red glow around highlights, 0 to 1", minimum: 0, maximum: 1),
    "blur": JSONSchema.number("Softness, 0 to 1", minimum: 0, maximum: 1),
    "key": JSONSchema.object([
      "color": JSONSchema.string("The background colour to remove (default green #00FF00)"),
      "tolerance": JSONSchema.number("How far from it counts as background, 0 to 1"),
      "softness": JSONSchema.number("How gradually the edge fades, 0 to 1"),
    ]),
  ])
}
