import ShadesCore

/// Moves a clip to another time and/or track, replacing whatever is in the way there. The space
/// it leaves stays empty. Clips linked to it move by the same time, on their own tracks.
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
    + "kind. It replaces whatever is in the way; the space it leaves stays empty. Linked clips "
    + "(its detached sound) move by the same time."
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
    let offset = to.map { project.onFrame($0) - clip.timelineStart } ?? .zero
    clip.timelineStart = clip.timelineStart + offset
    project.timeline.tracks[origin.track].clips.remove(at: origin.clip)
    project.timeline.tracks[destination].clear(from: clip.timelineStart, to: clip.timelineEnd)
    project.timeline.tracks[destination].add(clip)
    guard offset != .zero else {
      return
    }
    for partner in project.timeline.partners(of: clipID) {
      try project.slide(partner.id, by: offset)
    }
  }

}
