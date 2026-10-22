/// Argument schemas for grades and effects, shared by `set_look` and `add_adjustment`.
enum LookFields {

  // MARK: Internal

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
      "master": curve("All three colours"),
      "red": curve("Red only"),
      "green": curve("Green only"),
      "blue": curve("Blue only"),
    ]),
    "lut": JSONSchema.string("A .cube LUT: a file path, or a plugin's LUT by name"),
    "lut_amount": JSONSchema.number("How much of the LUT shows, 0 to 1", minimum: 0, maximum: 1),
    "qualifier": JSONSchema.object([
      "hue": JSONSchema.number("Hue to change, 0–1 (0 red, 0.08 skin, 0.33 green, 0.6 sky)"),
      "hue_width": JSONSchema.number("How far either side counts, 0 to 0.5 (default 0.08)"),
      "min_saturation": JSONSchema.number("Greyer colours aren't picked (default 0.15)"),
      "brightness": JSONSchema.array(
        "Brightness range picked, [from, to]",
        items: JSONSchema.number("0 to 1"),
      ),
      "softness": JSONSchema.number("Edge softness (default 0.05)"),
    ]),
    "window": JSONSchema.object([
      "shape": JSONSchema.string(
        "ellipse (default) or rectangle",
        values: ["ellipse", "rectangle"],
      ),
      "x": JSONSchema.number("Centre across the frame, 0–1"),
      "y": JSONSchema.number("Centre down the frame, 0–1"),
      "width": JSONSchema.number("Width as a fraction of the frame"),
      "height": JSONSchema.number("Height as a fraction of the frame"),
      "softness": JSONSchema.number("Edge softness, 0–1 (default 0.2)"),
      "inverted": JSONSchema.boolean("Grade outside the shape instead"),
    ]),
  ])
  static let effects = JSONSchema.object([
    "grain": JSONSchema.number("Film grain, 0 to 1", minimum: 0, maximum: 1),
    "vignette": JSONSchema.number("Darkened corners, 0 to 1", minimum: 0, maximum: 1),
    "halation": JSONSchema.number("Red glow around highlights, 0 to 1", minimum: 0, maximum: 1),
    "blur": JSONSchema.number("Softness, 0 to 1", minimum: 0, maximum: 1),
    "shader": JSONSchema.string(
      "A Metal shader effect: a .metal file's path or a plugin's shader. The file defines "
        + "float4 effect(float4 color, float2 uv, float time, float amount, texture2d<half> "
        + "source, sampler s), returning the new straight (not premultiplied) colour"
    ),
    "shader_amount": JSONSchema.number("The effect's strength, 0 to 1 (default 1)"),
    "portal": JSONSchema.object([
      "nesting": JSONSchema.number(
        "An endless zoom: the picture holds a copy of itself this many times smaller in its "
          + "middle, forever (1.5 to 10, default 3)"
      ),
      "travel": JSONSchema.number(
        "How far the view has zoomed in, in copies (1 brings the next one in to fill the "
          + "picture); keyframe portal to zoom on forever"
      ),
    ]),
    "key": JSONSchema.object([
      "color": JSONSchema.string("The background colour to remove (default green #00FF00)"),
      "tolerance": JSONSchema.number("How far from it counts as background, 0 to 1"),
      "softness": JSONSchema.number("How gradually the edge fades, 0 to 1"),
    ]),
  ])

  // MARK: Private

  /// One tone curve: `[input, output]` points from dark to light.
  private static func curve(_ channel: String) -> JSONValue {
    JSONSchema.array(
      "\(channel): [input, output] points 0–1",
      items: JSONSchema.array("A point", items: JSONSchema.number("0 to 1")),
    )
  }

}
