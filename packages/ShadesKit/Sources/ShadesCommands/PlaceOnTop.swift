import ShadesCore

/// Places media at a time on the lowest free track above the main one, like B-roll over A-roll.
public struct PlaceOnTop: ToolCommand {

  // MARK: Lifecycle

  public init(
    mediaID: Media.ID,
    at time: MediaTime,
    sourceStart: MediaTime? = nil,
    sourceEnd: MediaTime? = nil,
  ) {
    self.mediaID = mediaID
    at = time
    self.sourceStart = sourceStart
    self.sourceEnd = sourceEnd
  }

  // MARK: Public

  public static let title = "Place on Top"
  public static let name = "place_on_top"
  public static let summary = "Place media at a time on the lowest free track above V1 (or A1), "
    + "adding a track if every one is busy. Use it for B-roll and overlays."
  public static let parameters = JSONSchema.object(
    [
      "media_id": Fields.mediaID,
      "at": Fields.time("Where to place it"),
      "source_start": Fields.sourceStart,
      "source_end": Fields.sourceEnd,
    ],
    required: ["media_id", "at"],
  )

  public let mediaID: Media.ID
  public let at: MediaTime
  public let sourceStart: MediaTime?
  public let sourceEnd: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let media = try project.requireMedia(mediaID)
    let range = try project.sourceRange(of: media, from: sourceStart, to: sourceEnd)
    project.placeOnTop(media, range: range, at: project.onFrame(at))
  }

}
