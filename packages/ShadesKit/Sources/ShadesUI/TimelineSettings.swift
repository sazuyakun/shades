/// How the timeline is being worked on: the tool, snapping and zoom.
struct TimelineSettings {
  var tool = TimelineTool.select
  var isSnapping = true
  /// Zoom in points per second, or `nil` to fit the whole timeline.
  var pointsPerSecond: Double?
}
