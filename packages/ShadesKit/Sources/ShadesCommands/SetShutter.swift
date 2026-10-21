import ShadesCore

/// Sets how long anything moving blurs for across the whole timeline.
public struct SetShutter: ToolCommand {

  // MARK: Lifecycle

  public init(angle: Double) {
    self.angle = angle
  }

  // MARK: Public

  public static let title = "Set Shutter"
  public static let name = "set_shutter"
  public static let summary = "Set the timeline's shutter angle: how long anything moving blurs "
    + "for. 180 (the default) is film's natural blur, 360 a whole frame's smear, 0 none. "
    + "set_clip's motion_blur scales it for one clip."
  public static let parameters = JSONSchema.object(
    ["angle": JSONSchema.number("Degrees of a frame, 0 to 360", minimum: 0, maximum: 360)],
    required: ["angle"],
  )

  public let angle: Double

  public func apply(to project: inout Project) throws(CommandError) {
    guard (0 ... 360).contains(angle) else {
      throw rejected(.invalidValue("the shutter angle goes from 0 to 360 degrees"))
    }
    project.timeline.shutterAngle = angle
  }

}
