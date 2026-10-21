import ShadesCore

/// Unmarks a short.
public struct RemoveShort: ToolCommand {

  // MARK: Lifecycle

  public init(shortID: Short.ID) {
    self.shortID = shortID
  }

  // MARK: Public

  public static let title = "Remove Short"
  public static let name = "remove_short"
  public static let summary = "Unmark a short by its ID. The timeline itself doesn't change."
  public static let parameters = JSONSchema.object(
    ["short_id": JSONSchema.string("ID of a short, from get_project")],
    required: ["short_id"],
  )

  public let shortID: Short.ID

  public func apply(to project: inout Project) throws(CommandError) {
    try project.timeline.shorts.remove(at: project.requireShort(shortID))
  }

}
