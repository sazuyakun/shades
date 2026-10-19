import ShadesCore

/// Removes a clip's keyframes: all of them, one property's, or the ones at one moment.
public struct RemoveKeyframes: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, property: AnimatedProperty? = nil, at time: MediaTime? = nil) {
    self.clipID = clipID
    self.property = property
    at = time
  }

  // MARK: Public

  public static let title = "Remove Keyframes"
  public static let name = "remove_keyframes"
  public static let summary = "Remove a clip's keyframes: all of them, only one property's, or "
    + "only those at one moment. The property goes back to its fixed value once none are left."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "property": JSONSchema.string(
        "Only this property's keyframes",
        values: AnimatedProperty.allCases.map(\.rawValue),
      ),
      "at": Fields.time("Only the keyframes at this moment"),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let property: AnimatedProperty?
  public let at: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    var clip = project.timeline.tracks[location.track].clips[location.clip]
    let time = at.map { clip.sourceTime(at: project.onFrame($0)) }
    let before = clip.keyframes.count
    clip.keyframes.removeAll { keyframe in
      (property.map { $0 == keyframe.property } ?? true) &&
        (time.map { $0 == keyframe.time } ?? true)
    }
    guard clip.keyframes.count < before else {
      throw rejected(.invalidValue("the clip has no keyframes like that"))
    }
    project.timeline.tracks[location.track].clips[location.clip] = clip
  }

}
