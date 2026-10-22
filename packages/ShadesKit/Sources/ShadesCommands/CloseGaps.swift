import ShadesCore

/// Slides clips left so they play back to back with no gaps. Clips linked to a moved clip move
/// with it; a track holding clips linked to one closed earlier doesn't close on its own.
public struct CloseGaps: ToolCommand {

  // MARK: Lifecycle

  public init(track: String? = nil) {
    self.track = track
  }

  // MARK: Public

  public static let title = "Close Gaps"
  public static let name = "close_gaps"
  public static let summary = "Slide clips left so they play back to back from the start, on one "
    + "track or (by default) every track. Linked clips (a video's detached sound) follow their "
    + "video rather than closing up on their own."
  public static let parameters = JSONSchema.object(["track": Fields.track])

  public let track: String?

  public func apply(to project: inout Project) throws(CommandError) {
    let indices = try track.map { label throws(CommandError) in [try project.requireTrack(label)] }
      ?? Array(project.timeline.tracks.indices)
    let tracks = project.timeline.tracks
    // why: pictures close first, so linked sound follows its video, not the other way round.
    let order = indices.filter { tracks[$0].kind != .audio } + indices
      .filter { tracks[$0].kind == .audio }
    var closed = Set<Int>()
    for index in order {
      let clips = project.timeline.tracks[index].clips
      let follows = clips.contains { clip in
        project.timeline.partners(of: clip.id).contains { partner in
          project.timeline.location(ofClip: partner.id).map { closed.contains($0.track) } == true
        }
      }
      guard !follows else {
        continue
      }
      project.timeline.tracks[index].closeGaps()
      closed.insert(index)
      for (before, after) in zip(clips, project.timeline.tracks[index].clips)
        where before.id == after.id
      {
        let offset = after.timelineStart - before.timelineStart
        for partner in project.timeline.partners(of: after.id) where offset != .zero {
          let track = try project.requireClip(partner.id).track
          if !closed.contains(track) {
            try project.slide(partner.id, by: offset)
          }
        }
      }
    }
  }

}
