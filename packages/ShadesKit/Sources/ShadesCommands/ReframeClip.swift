import ShadesCore

/// Zooms a clip to fill the 4:3 frame (no black bars) and shifts it to keep the subject in view,
/// never so far that an edge shows.
public struct ReframeClip: ToolCommand {

  // MARK: Lifecycle

  public init(clipID: Clip.ID, centerX: Double? = nil, centerY: Double? = nil) {
    self.clipID = clipID
    self.centerX = centerX
    self.centerY = centerY
  }

  // MARK: Public

  public static let title = "Reframe"
  public static let name = "reframe_clip"
  public static let summary = "Zoom a clip to fill the 4:3 frame with no black bars, shifted to "
    + "keep the subject in view. center_x / center_y say where the subject is across the clip's "
    + "picture (0–1, default the middle); auto_reframe works them out from the cut-out."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "center_x": JSONSchema.number(
        "Subject's horizontal position, 0 left to 1 right",
        minimum: 0,
        maximum: 1,
      ),
      "center_y": JSONSchema.number(
        "Subject's vertical position, 0 top to 1 bottom",
        minimum: 0,
        maximum: 1,
      ),
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let centerX: Double?
  public let centerY: Double?

  public func apply(to project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    guard let mediaID = clip.mediaID else {
      throw rejected(.invalidValue("only video clips can be reframed"))
    }
    let media = try project.requireMedia(mediaID)
    guard media.hasVideo, media.width > 0, media.height > 0 else {
      throw rejected(.invalidValue("only video clips can be reframed"))
    }
    let pictureAspect = Double(media.width) / Double(media.height)
    let frameAspect = Double(project.timeline.format.width) / Double(project.timeline.format.height)
    let fill = max(pictureAspect / frameAspect, frameAspect / pictureAspect)
    let reach = (fill - 1) / 2
    var transform = ClipTransform(scale: fill)
    if pictureAspect > frameAspect {
      transform.x = min(max(-((centerX ?? 0.5) - 0.5) * fill, -reach), reach)
    } else {
      transform.y = min(max(-((centerY ?? 0.5) - 0.5) * fill, -reach), reach)
    }
    project.timeline.tracks[location.track].clips[location.clip].transform = transform
  }

}
