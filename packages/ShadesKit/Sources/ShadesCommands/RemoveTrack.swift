import ShadesCore

/// Removes a track and every clip on it.
public struct RemoveTrack: ToolCommand {
  public init(track: String) {
    self.track = track
  }

  public static let title = "Remove Track"
  public static let name = "remove_track"
  public static let summary = "Remove a track and every clip on it. The last video track stays."
  public static let parameters = JSONSchema.object(["track": Fields.track], required: ["track"])

  public let track: String

  public func apply(to project: inout Project) throws(CommandError) {
    let index = try project.requireTrack(track)
    let videoTracks = project.timeline.tracks.count { $0.kind == .video }
    guard project.timeline.tracks[index].kind == .audio || videoTracks > 1 else {
      throw rejected(.lastVideoTrack)
    }
    project.timeline.tracks.remove(at: index)
  }
}
