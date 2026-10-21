import ShadesCore

/// How the editor is being worked on: the timeline tool, drawing or tracking in the viewer,
/// snapping, zoom and the short being worked on.
struct TimelineSettings {
  var tool = TimelineTool.select
  /// Dragging in the viewer draws lines (the Draw tool, P).
  var isDrawing = false
  /// Dragging in the viewer draws a box to track (the Track tool, ⌥T).
  var isTracking = false
  /// The scopes show beside the viewer.
  var showsScopes = false
  var isSnapping = true
  /// Zoom in points per second, or `nil` to fit the whole timeline.
  var pointsPerSecond: Double?
  /// The short clicked above the timeline, which the short actions change.
  var selectedShort: Short.ID?
}
