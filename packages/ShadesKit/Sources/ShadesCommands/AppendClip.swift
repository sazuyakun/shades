import ShadesCore

/// Places media (or part of it) at the end of a track.
public struct AppendClip: ToolCommand {

  // MARK: Lifecycle

  public init(
    mediaID: Media.ID,
    track: String? = nil,
    sourceStart: MediaTime? = nil,
    sourceEnd: MediaTime? = nil,
  ) {
    self.mediaID = mediaID
    self.track = track
    self.sourceStart = sourceStart
    self.sourceEnd = sourceEnd
  }

  // MARK: Public

  public static let title = "Append Clip"
  public static let name = "append_clip"
  public static let summary = "Place media, or the part between source_start and source_end, "
    + "at the end of a track (V1, or A1 for sound-only media, by default)."
  public static let parameters = JSONSchema.object(
    [
      "media_id": Fields.mediaID,
      "track": Fields.track,
      "source_start": Fields.sourceStart,
      "source_end": Fields.sourceEnd,
    ],
    required: ["media_id"],
  )

  public let mediaID: Media.ID
  public let track: String?
  public let sourceStart: MediaTime?
  public let sourceEnd: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let media = try project.requireMedia(mediaID)
    let range = try project.sourceRange(of: media, from: sourceStart, to: sourceEnd)
    let index = try project.track(for: media, labeled: track)
    let start = project.timeline.tracks[index].end
    project.timeline.tracks[index].add(project.newClip(of: media, range: range, at: start))
  }

}
