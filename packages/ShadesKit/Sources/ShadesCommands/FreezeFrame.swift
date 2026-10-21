import ShadesCore

/// Holds one frame of a video clip for a while: the clip splits there and the held frame plays
/// between its halves, pushing later clips on the track right.
public struct FreezeFrame: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, at time: MediaTime, duration: MediaTime) {
    self.clipID = clipID
    at = time
    self.duration = duration
  }

  // MARK: Public

  public static let title = "Freeze Frame"
  public static let name = "freeze_frame"
  public static let summary = "Hold the frame a video clip shows at a moment for a while: the "
    + "clip is split there and the held frame plays between the halves (at the clip's end, its "
    + "last frame holds after it). Later clips on that track move right; other tracks don't. "
    + "The freeze is silent and keeps the clip's look at that frame; move the camera over it "
    + "with set_camera."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "at": Fields.time("The frame to hold, within the clip"),
      "duration": JSONSchema.number("How long it holds, in seconds", minimum: 0),
    ],
    required: ["clip_id", "at", "duration"],
  )

  public let clipID: Clip.ID
  public let at: MediaTime
  public let duration: MediaTime

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    guard
      project.timeline.tracks[location.track].kind == .video,
      let mediaID = clip.mediaID, try project.requireMedia(mediaID).hasVideo,
      try !project.requireMedia(mediaID).isStill, !clip.isFrozen
    else {
      throw rejected(.invalidValue("only a moving video clip has frames to freeze"))
    }
    let time = project.onFrame(at)
    guard clip.timelineStart <= time, time <= clip.timelineEnd else {
      throw rejected(.invalidRange(
        "the frame must fall within the clip, \(clip.timelineStart.seconds)–"
          + "\(clip.timelineEnd.seconds) s"
      ))
    }
    let length = project.onFrame(duration)
    guard length > .zero else {
      throw rejected(.invalidValue("a freeze lasts at least a frame"))
    }
    let shown = time == clip.timelineEnd ? time - project.timeline.format.frameDuration : time
    var freeze = clip.withNewID()
    freeze.sourceStart = clip.sourceTime(at: shown)
    freeze.speed = 0
    freeze.keyframes.removeAll { $0.property == .speed }
    freeze.timelineStart = time
    freeze.duration = length
    freeze.fadeIn = .zero
    freeze.fadeOut = .zero
    project.timeline.tracks[location.track].shift(from: time, by: length)
    project.timeline.tracks[location.track].add(freeze)
  }

}
