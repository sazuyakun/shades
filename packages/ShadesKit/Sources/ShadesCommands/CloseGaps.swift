import ShadesCore

/// Slides clips left so they play back to back with no gaps.
public struct CloseGaps: ToolCommand {
  public init(track: String? = nil) {
    self.track = track
  }

  public static let title = "Close Gaps"
  public static let name = "close_gaps"
  public static let summary = "Slide clips left so they play back to back from the start, on one "
    + "track or (by default) every track."
  public static let parameters = JSONSchema.object(["track": Fields.track])

  public let track: String?

  public func apply(to project: inout Project) throws(CommandError) {
    let indices = try track.map { label throws(CommandError) in [try project.requireTrack(label)] }
      ?? Array(project.timeline.tracks.indices)
    for index in indices {
      project.timeline.tracks[index].closeGaps()
    }
  }
}
