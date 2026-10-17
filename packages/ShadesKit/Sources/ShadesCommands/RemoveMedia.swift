import ShadesCore

/// Removes a media file from the project, along with every clip that uses it.
public struct RemoveMedia: ToolCommand {

  // MARK: Lifecycle

  public init(mediaID: Media.ID) {
    self.mediaID = mediaID
  }

  // MARK: Public

  public static let title = "Remove Media"
  public static let name = "remove_media"
  public static let summary = "Remove imported media from the project, and every clip using it."
  public static let parameters = JSONSchema.object(
    ["media_id": Fields.mediaID],
    required: ["media_id"],
  )

  public let mediaID: Media.ID

  public func apply(to project: inout Project) throws(CommandError) {
    _ = try project.requireMedia(mediaID)
    project.media.removeAll { $0.id == mediaID }
    for index in project.timeline.tracks.indices {
      project.timeline.tracks[index].clips.removeAll { $0.mediaID == mediaID }
    }
  }

}
