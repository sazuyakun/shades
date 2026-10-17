import ShadesCore

/// Places media at a time and pushes later clips on that track right to make room.
public struct InsertClip: ToolCommand {

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

  public static let title = "Insert Clip"
  public static let name = "insert_clip"
  public static let summary = "Insert media at a time on a track. Later clips on that track move "
    + "right; a clip under the time is split. Other tracks don't move."
  public static let parameters = JSONSchema.object(
    [
      "media_id": Fields.mediaID,
      "at": Fields.time("Where to insert"),
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
    project.timeline.tracks[index].shift(from: time, by: range.duration)
    project.timeline.tracks[index].add(Clip(
      mediaID: media.id,
      sourceStart: range.start,
      duration: range.duration,
      timelineStart: time,
      isAudioEnabled: media.hasAudio,
    ))
  }

}
