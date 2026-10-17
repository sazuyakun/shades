/// Argument schemas shared by several tools, so each field reads the same everywhere.
enum Fields {
  static let mediaID = JSONSchema.string("ID of imported media, from import_media or get_project")
  static let clipID = JSONSchema.string("ID of a clip on the timeline, from get_project")
  static let clipIDs = JSONSchema.array("IDs of clips on the timeline", items: clipID)
  static let track = JSONSchema.string("Track label like V1, V2 or A1. Video tracks stack upward")
  static let sourceStart = JSONSchema.number(
    "Where in the media file to start, in seconds (default: the beginning)",
    minimum: 0,
  )
  static let sourceEnd = JSONSchema.number(
    "Where in the media file to stop, in seconds (default: the end)",
    minimum: 0,
  )
  static let ripple = JSONSchema.boolean(
    "Move later clips on the same track to close or open the space (default false)"
  )

  /// A time on the timeline, in seconds.
  static func time(_ description: String) -> JSONValue {
    JSONSchema.number(description + ", in seconds on the timeline", minimum: 0)
  }
}
