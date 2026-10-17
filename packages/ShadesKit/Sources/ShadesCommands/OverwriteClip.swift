import ShadesCore

/// Places media at a time, replacing whatever was there on that track.
public struct OverwriteClip: ToolCommand {

  // MARK: Lifecycle

  public init(
    mediaID: Media.ID,
    at time: MediaTime,
    track: String? = nil,
    sourceStart: MediaTime? = nil,
    sourceEnd: MediaTime? = nil,
  ) {
    self.mediaID = mediaID
    at = time
    self.track = track
    self.sourceStart = sourceStart
    self.sourceEnd = sourceEnd
  }

  // MARK: Public

  public static let title = "Overwrite Clip"
  public static let name = "overwrite_clip"
  public static let summary = "Place media at a time on a track, replacing whatever was there. "
    + "Nothing else moves."
  public static let parameters = JSONSchema.object(
    [
      "media_id": Fields.mediaID,
      "at": Fields.time("Where to place it"),
      "track": Fields.track,
      "source_start": Fields.sourceStart,
      "source_end": Fields.sourceEnd,
    ],
    required: ["media_id", "at"],
  )

  public let mediaID: Media.ID
  public let at: MediaTime
  public let track: String?
  public let sourceStart: MediaTime?
  public let sourceEnd: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let media = try project.requireMedia(mediaID)
    let range = try project.sourceRange(of: media, from: sourceStart, to: sourceEnd)
    let index = try project.track(for: media, labeled: track)
    let time = project.onFrame(at)
    project.timeline.tracks[index].clear(from: time, to: time + range.duration)
    project.timeline.tracks[index].add(Clip(
      mediaID: media.id,
      sourceStart: range.start,
      duration: range.duration,
      timelineStart: time,
      isAudioEnabled: media.hasAudio,
    ))
  }

}
