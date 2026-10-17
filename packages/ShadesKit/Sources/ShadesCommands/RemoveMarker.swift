import ShadesCore

/// Removes a marker.
public struct RemoveMarker: ToolCommand {

  // MARK: Lifecycle

  public init(markerID: Marker.ID) {
    self.markerID = markerID
  }

  // MARK: Public

  public static let title = "Remove Marker"
  public static let name = "remove_marker"
  public static let summary = "Remove a marker by its ID."
  public static let parameters = JSONSchema.object(
    ["marker_id": JSONSchema.string("ID of a marker, from get_project")],
    required: ["marker_id"],
  )

  public let markerID: Marker.ID

  public func apply(to project: inout Project) throws(CommandError) {
    guard project.timeline.markers.contains(where: { $0.id == markerID }) else {
      throw rejected(.markerNotFound(markerID))
    }
    project.timeline.markers.removeAll { $0.id == markerID }
  }

}
