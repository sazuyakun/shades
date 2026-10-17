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

  /// A time on the timeline, in seconds.
  public static func time(_ description: String) -> JSONValue {
    JSONSchema.number(description + ", in seconds on the timeline", minimum: 0)
  }
}
