import ShadesCore

/// Moves a clip to another time and/or track, replacing whatever is in the way there. The space
/// it leaves stays empty.
public struct MoveClip: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, to time: MediaTime? = nil, track: String? = nil) {
    self.clipID = clipID
    to = time
    self.track = track
  }

  // MARK: Public

  public static let title = "Move Clip"
  public static let name = "move_clip"
  public static let summary = "Move a clip to a new start time and/or another track of the same "
    + "kind. It replaces whatever is in the way; the space it leaves stays empty."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID, "to": Fields.time("New start"), "track": Fields.track],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let to: MediaTime?
  public let track: String?

  public func apply(to project: inout Project) throws(CommandError) {
    let origin = try project.requireClip(clipID)
    var clip = project.timeline.tracks[origin.track].clips[origin.clip]
    let kind = project.timeline.tracks[origin.track].kind
    let destination = try track.map(project.requireTrack) ?? origin.track
    guard project.timeline.tracks[destination].kind == kind else {
      throw rejected(.wrongTrackKind(track: track?.uppercased() ?? "", needs: kind))
    }
    if let to {
      clip.timelineStart = project.onFrame(to)
    }
    project.timeline.tracks[origin.track].clips.remove(at: origin.clip)
    project.timeline.tracks[destination].clear(from: clip.timelineStart, to: clip.timelineEnd)
    project.timeline.tracks[destination].add(clip)
  }

}
