import ShadesCore

/// Sets how footage of another shape is sized as it's placed on the timeline.
public struct SetDefaultFit: ToolCommand {

  // MARK: Lifecycle

  public init(fit: ClipFit) {
    self.fit = fit
  }

  // MARK: Public

  public static let title = "Set Default Fit"
  public static let name = "set_default_fit"
  public static let summary = "Set how footage of another shape (16:9 in the 4:3 frame) is sized "
    + "as it's placed: fill (covers the frame, edges cropped; new projects' default) or fit "
    + "(inside the frame, black around). Clips already placed keep their size; set_clip fit "
    + "changes one."
  public static let parameters = JSONSchema.object(
    ["fit": JSONSchema.string("fill or fit", values: ["fill", "fit"])],
    required: ["fit"],
  )

  public let fit: ClipFit

  public func apply(to project: inout Project) throws(CommandError) {
    project.timeline.defaultFit = fit
  }

}
