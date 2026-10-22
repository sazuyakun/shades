import ShadesCore

/// Removes clips and the clips linked to them, leaving gaps, or closing them with ripple.
public struct DeleteClips: ToolCommand {

  // MARK: Lifecycle

  public init(clipIDs: [Clip.ID], ripple: Bool? = nil) {
    self.clipIDs = clipIDs
    self.ripple = ripple
  }

  // MARK: Public

  public static let title = "Delete Clips"
  public static let name = "delete_clips"
  public static let summary = "Remove clips and the clips linked to them. They leave gaps unless "
    + "ripple is true, which slides later clips on their tracks left."
  public static let parameters = JSONSchema.object(
    ["clip_ids": Fields.clipIDs, "ripple": Fields.ripple],
    required: ["clip_ids"],
  )

  public let clipIDs: [Clip.ID]
  public let ripple: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    var doomed = [Clip]()
    for id in clipIDs {
      let location = try project.requireClip(id)
      doomed.append(project.timeline.tracks[location.track].clips[location.clip])
      doomed += project.timeline.partners(of: id)
    }
    var seen = Set<Clip.ID>()
    doomed = doomed.filter { seen.insert($0.id).inserted }
    // why: removing the latest clips first keeps the earlier ones' positions valid for ripple.
    for clip in doomed.sorted(by: { $0.timelineStart > $1.timelineStart }) {
      let track = try project.requireClip(clip.id).track
      project.timeline.tracks[track].clear(from: clip.timelineStart, to: clip.timelineEnd)
      if ripple == true {
        project.timeline.tracks[track].shift(from: clip.timelineEnd, by: .zero - clip.duration)
      }
    }
  }

}
