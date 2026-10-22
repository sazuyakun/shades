import ShadesCore

/// Sets how a clip comes in from the clip just before it on its track: a transition centred on
/// the cut, or a plain cut.
public struct SetTransition: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, kind: TransitionKind?, duration: MediaTime? = nil) {
    self.clipID = clipID
    self.kind = kind
    self.duration = duration
  }

  // MARK: Public

  public static let title = "Set Transition"
  public static let name = "set_transition"
  public static let summary = "Set the transition into a clip from the clip right before it on "
    + "its track (they must touch): dissolve, dipToBlack, flash, whip, push, slices, tiles, "
    + "iris (a circle opening from the middle) or portal (zooming in through a small frame of "
    + "the next shot until it fills the picture), centred on the cut. Leave out kind for a plain "
    + "cut. Footage past the clips' ends is used when it exists; otherwise the edge frame holds."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": JSONSchema.string("The clip coming in"),
      "kind": JSONSchema.string(
        "The transition; leave out for a cut",
        values: TransitionKind.allCases.map(\.rawValue),
      ),
      "duration": JSONSchema.number("Its length in seconds (default 0.5)", minimum: 0.04),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let kind: TransitionKind?
  public let duration: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let track = project.timeline.tracks[location.track]
    let incoming = track.clips[location.clip]
    guard let kind else {
      project.timeline.tracks[location.track].clips[location.clip].transitionIn = nil
      return
    }
    guard
      location.clip > 0,
      track.clips[location.clip - 1].timelineEnd == incoming.timelineStart
    else {
      throw rejected(.invalidValue("a transition needs a clip right before this one on its track"))
    }
    let outgoing = track.clips[location.clip - 1]
    let length = project.onFrame(duration ?? MediaTime(seconds: 0.5))
    let longest = min(outgoing.duration, incoming.duration)
    guard length > .zero, length <= longest else {
      throw rejected(.invalidRange(
        "the transition can be at most \(longest.seconds) s, the shorter clip's length"
      ))
    }
    project.timeline.tracks[location.track].clips[location.clip].transitionIn = Transition(
      kind: kind,
      duration: length,
    )
  }

}
