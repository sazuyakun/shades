import ShadesCore

/// Marks a stretch of the timeline as a short, to export on its own on the vertical canvas.
public struct AddShort: ToolCommand {

  // MARK: Lifecycle

  public init(name: String, start: MediaTime, end: MediaTime) {
    self.name = name
    self.start = start
    self.end = end
  }

  // MARK: Public

  public static let title = "Mark Short"
  public static let name = "add_short"
  public static let summary = "Mark a stretch of the timeline as a Reel/Short, by name. Shorts "
    + "export together, each on the 9:16 canvas (export with kind shorts)."
  public static let parameters = JSONSchema.object(
    [
      "name": JSONSchema.string("What it's called, like \"Short 1 · Chul ka keeda\""),
      "start": Fields.time("Where it starts"),
      "end": Fields.time("Where it ends"),
    ],
    required: ["name", "start", "end"],
  )

  public let name: String
  public let start: MediaTime
  public let end: MediaTime

  public func apply(to project: inout Project) throws(CommandError) {
    let range = TimeRange(start: project.onFrame(start), end: project.onFrame(end))
    guard range.start >= .zero, range.end > range.start else {
      throw rejected(.invalidRange("a short needs an end after its start"))
    }
    guard range.end <= project.timeline.duration else {
      throw rejected(.invalidRange("the short ends after the timeline does"))
    }
    project.timeline.shorts.append(Short(name: name, range: range))
  }

}
