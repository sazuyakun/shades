import ShadesCore

/// Drops a named marker on the timeline.
public struct AddMarker: ToolCommand {

  // MARK: Lifecycle

  public init(at time: MediaTime, name: String? = nil) {
    at = time
    self.name = name
  }

  // MARK: Public

  public static let title = "Add Marker"
  public static let name = "add_marker"
  public static let summary = "Add a named marker at a time on the timeline."
  public static let parameters = JSONSchema.object(
    ["at": Fields.time("Where"), "name": JSONSchema.string("A short label")],
    required: ["at"],
  )

  public let at: MediaTime
  public let name: String?

  public func apply(to project: inout Project) throws(CommandError) {
    let marker = Marker(time: project.onFrame(at), name: name ?? "")
    let index = project.timeline.markers.firstIndex { $0.time > marker.time }
      ?? project.timeline.markers.endIndex
    project.timeline.markers.insert(marker, at: index)
  }

}
