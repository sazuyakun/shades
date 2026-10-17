import ShadesCore

/// Cuts a clip in two at a time.
public struct SplitClip: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, at time: MediaTime) {
    self.clipID = clipID
    at = time
  }

  // MARK: Public

  public static let title = "Split Clip"
  public static let name = "split_clip"
  public static let summary = "Cut a clip in two at a time inside it. The second half gets a new "
    + "clip ID."
  public static let parameters = JSONSchema.object(
    ["clip_id": Fields.clipID, "at": Fields.time("Where to cut")],
    required: ["clip_id", "at"],
  )

  public let clipID: Clip.ID
  public let at: MediaTime

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    let time = project.onFrame(at)
    guard clip.timelineStart < time, time < clip.timelineEnd else {
      throw rejected(.invalidRange("the cut must fall inside the clip"))
    }
    project.timeline.tracks[location.track].split(at: time)
  }

}
