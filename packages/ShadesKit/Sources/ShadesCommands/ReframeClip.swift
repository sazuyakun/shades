import ShadesCore

/// Zooms a clip to fill the 4:3 frame (no black bars) and shifts it to keep the subject in view,
/// never so far that an edge shows. The framing is locked: it replaces any x / y keyframes.
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
  public static let summary = "Zoom a clip to fill the 4:3 frame with no black bars, locked on "
    + "one framing that keeps the subject in view. center_x / center_y say where the subject is "
    + "across the clip's picture (0–1, default the middle); auto_reframe works them out from the "
    + "cut-out, or pans with the subject."
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
    let framing = try Framing(of: clipID, in: project)
    var clip = framing.clip
    clip.transform = ClipTransform(
      x: framing.offset(forSubjectAt: centerX ?? 0.5, axis: .x),
      y: framing.offset(forSubjectAt: centerY ?? 0.5, axis: .y),
      scale: framing.scale,
    )
    clip.keyframes.removeAll { $0.property == .x || $0.property == .y }
    project.timeline.tracks[framing.location.track].clips[framing.location.clip] = clip
  }

}
