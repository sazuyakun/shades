import Foundation
import ShadesCore

/// Renames a short or moves its start or end.
public struct SetShort: ToolCommand {

  // MARK: Lifecycle

  public init(
    shortID: Short.ID,
    name: String? = nil,
    start: MediaTime? = nil,
    end: MediaTime? = nil,
  ) {
    self.shortID = shortID
    self.name = name
    self.start = start
    self.end = end
  }

  // MARK: Public

  public static let title = "Change Short"
  public static let name = "set_short"
  public static let summary = "Rename a marked short or move its start or end. Only the fields "
    + "given change."
  public static let parameters = JSONSchema.object(
    [
      "short_id": JSONSchema.string("ID of a short, from get_project"),
      "name": JSONSchema.string("Its new name"),
      "start": Fields.time("Where it now starts"),
      "end": Fields.time("Where it now ends"),
    ],
    required: ["short_id"],
  )

  public let shortID: Short.ID
  public let name: String?
  public let start: MediaTime?
  public let end: MediaTime?

  public func apply(to project: inout Project) throws(CommandError) {
    let index = try project.requireShort(shortID)
    var short = project.timeline.shorts[index]
    if let name {
      guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
        throw rejected(.invalidValue("a short needs a name"))
      }
      short.name = name
    }
    short.range = try project.shortRange(
      from: start ?? short.range.start,
      to: end ?? short.range.end,
    )
    project.timeline.shorts[index] = short
  }

}
