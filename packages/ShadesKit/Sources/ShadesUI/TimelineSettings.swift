/// How the editor is being worked on: the timeline tool, drawing in the viewer, snapping and zoom.
struct TimelineSettings {
  var tool = TimelineTool.select
  /// Dragging in the viewer draws lines (the Draw tool, P).
  var isDrawing = false
  var isSnapping = true
  /// Zoom in points per second, or `nil` to fit the whole timeline.
  var pointsPerSecond: Double?
}
