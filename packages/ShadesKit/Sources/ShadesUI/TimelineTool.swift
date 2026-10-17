/// What dragging and clicking on the timeline does.
enum TimelineTool {
  /// Select and move clips; dragging an edge trims without moving other clips.
  case select
  /// Click a clip to cut it there.
  case blade
  /// Like select, but dragging an edge ripples: later clips follow.
  case trim
}
