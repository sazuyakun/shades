import ShadesCore

/// Argument schemas shared by several tools, so each field reads the same everywhere.
public enum Fields {
  public static let mediaID = JSONSchema
    .string("ID of imported media, from import_media or get_project")
  public static let clipID = JSONSchema.string("ID of a clip on the timeline, from get_project")
  public static let clipIDs = JSONSchema.array("IDs of clips on the timeline", items: clipID)
  public static let track = JSONSchema
    .string("Track label like V1, V2 or A1. Video tracks stack upward")
  public static let sourceStart = JSONSchema.number(
    "Where in the media file to start, in seconds (default: the beginning)",
    minimum: 0,
  )
  public static let sourceEnd = JSONSchema.number(
    "Where in the media file to stop, in seconds (default: the end)",
    minimum: 0,
  )
  public static let ripple = JSONSchema.boolean(
    "Move later clips on the same track to close or open the space (default false)"
  )

  public static let textStyle = JSONSchema.object([
    "font": JSONSchema
      .string("A font's name, from the Mac or a plugin (default the system's bold)"),
    "size": JSONSchema.number("Letter height as a fraction of the frame height (default 0.075)"),
    "color": JSONSchema.string("Fill colour like #FFFFFF"),
    "outline_color": JSONSchema.string("Outline colour like #000000"),
    "outline": JSONSchema.number("Outline thickness as a fraction of the size, 0 for none"),
    "shadow": JSONSchema.boolean("A soft drop shadow (default true)"),
    "align": JSONSchema.string("How lines line up", values: TextAlign.allCases.map(\.rawValue)),
    "anchor": JSONSchema.string(
      "bottom (like a caption, default) or center (like a title); x and y move it from there",
      values: TextAnchor.allCases.map(\.rawValue),
    ),
    "highlight": JSONSchema.string("The spoken word's colour for the highlight reveal"),
    "arc": JSONSchema.number(
      "Bend the text along a circle, in degrees: positive arches up, negative dips (default 0)"
    ),
    "spacing": JSONSchema.number(
      "Extra room between letters as a fraction of the size; negative tightens (default 0)"
    ),
    "extrusion": JSONSchema.object([
      "depth": JSONSchema.number(
        "How deep the solid letters go, as a fraction of the size (default 0.3)"
      ),
      "bevel": JSONSchema.number(
        "How far the slope round their front edges reaches in, as a fraction of the size; 0 "
          + "is sharp (default 0.03)"
      ),
    ]),
  ])
  public static let reveal = JSONSchema.string(
    "How the words come on: none, pop (each pops in as it's said), highlight (the spoken word "
      + "lights up) or typewriter",
    values: TextReveal.allCases.map(\.rawValue),
  )

  public static let words = JSONSchema.array(
    "When each word is said, in order, one per word of the text, in seconds from the clip's "
      + "start (the reveal follows them; without them words are spread over the start)",
    items: JSONSchema.object(
      [
        "text": JSONSchema.string("The word"),
        "start": JSONSchema.number("When it starts", minimum: 0),
        "end": JSONSchema.number("When it ends", minimum: 0),
      ],
      required: ["text", "start", "end"],
    ),
  )

  /// A time on the timeline, in seconds.
  public static func time(_ description: String) -> JSONValue {
    JSONSchema.number(description + ", in seconds on the timeline", minimum: 0)
  }
}
