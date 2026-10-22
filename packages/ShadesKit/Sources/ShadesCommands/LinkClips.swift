import Foundation
import ShadesCore

/// Links clips on different tracks, like a video and the sound recorded with it, so moving,
/// trimming, splitting and deleting one does the same to the others.
public struct LinkClips: ToolCommand {

  // MARK: Lifecycle

  public init(clipIDs: [Clip.ID]) {
    self.clipIDs = clipIDs
  }

  // MARK: Public

  public static let title = "Link Clips"
  public static let name = "link_clips"
  public static let summary = "Link clips on different tracks (a video and its sound, say) so "
    + "moving, trimming, splitting, deleting and rippling one does the same to the others. "
    + "detach_audio links the sound it detaches by itself; unlink_clips undoes a link."
  public static let parameters = JSONSchema.object(
    ["clip_ids": Fields.clipIDs],
    required: ["clip_ids"],
  )

  public let clipIDs: [Clip.ID]

  public func apply(to project: inout Project) throws(CommandError) {
    var locations = [(track: Int, clip: Int)]()
    for id in clipIDs {
      try locations.append(project.requireClip(id))
    }
    guard Set(locations.map(\.track)).count >= 2 else {
      throw rejected(.cannotLink("pick clips on at least two tracks"))
    }
    let link = UUID()
    for location in locations {
      project.timeline.tracks[location.track].clips[location.clip].link = link
    }
  }

}
