import ShadesCore

/// Unlinks clips from the clips they're linked to, so each can be edited on its own.
public struct UnlinkClips: ToolCommand {

  // MARK: Lifecycle

  public init(clipIDs: [Clip.ID]) {
    self.clipIDs = clipIDs
  }

  // MARK: Public

  public static let title = "Unlink Clips"
  public static let name = "unlink_clips"
  public static let summary = "Unlink clips from the clips they're linked to (and those from "
    + "them), so each moves and trims on its own, e.g. to slip a video's sound for a J-cut."
  public static let parameters = JSONSchema.object(
    ["clip_ids": Fields.clipIDs],
    required: ["clip_ids"],
  )

  public let clipIDs: [Clip.ID]

  public func apply(to project: inout Project) throws(CommandError) {
    var unlinked = [Clip.ID]()
    for id in clipIDs {
      _ = try project.requireClip(id)
      unlinked += [id] + project.timeline.partners(of: id).map(\.id)
    }
    for id in unlinked {
      let location = try project.requireClip(id)
      project.timeline.tracks[location.track].clips[location.clip].link = nil
    }
  }

}
