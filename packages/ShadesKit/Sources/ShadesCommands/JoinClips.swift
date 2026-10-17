import ShadesCore

/// Joins neighbouring pieces of the same media back into one clip, undoing splits.
public struct JoinClips: ToolCommand {

  // MARK: Lifecycle

  public init(clipIDs: [Clip.ID]) {
    self.clipIDs = clipIDs
  }

  // MARK: Public

  public static let title = "Join Clips"
  public static let name = "join_clips"
  public static let summary = "Join back-to-back clips on one track that continue the same media "
    + "(like the halves of a split) into one clip."
  public static let parameters = JSONSchema.object(
    ["clip_ids": Fields.clipIDs],
    required: ["clip_ids"],
  )

  public let clipIDs: [Clip.ID]

  public func apply(to project: inout Project) throws(CommandError) {
    guard clipIDs.count >= 2 else {
      throw rejected(.cannotJoin("pick at least two clips"))
    }
    var locations = [(track: Int, clip: Int)]()
    for id in clipIDs {
      try locations.append(project.requireClip(id))
    }
    guard let track = locations.first?.track, locations.allSatisfy({ $0.track == track }) else {
      throw rejected(.cannotJoin("they must be on the same track"))
    }
    let clips = locations.map { project.timeline.tracks[track].clips[$0.clip] }
      .sorted { $0.timelineStart < $1.timelineStart }
    for (left, right) in zip(clips, clips.dropFirst()) {
      guard
        left.mediaID == right.mediaID, left.timelineEnd == right.timelineStart,
        left.sourceStart + left.duration == right.sourceStart
      else {
        throw rejected(.cannotJoin("they must be back to back pieces of the same media"))
      }
    }
    guard var joined = clips.first, let last = clips.last else {
      return
    }
    joined.duration = last.timelineEnd - joined.timelineStart
    let removed = Set(clips.map(\.id))
    project.timeline.tracks[track].clips.removeAll { removed.contains($0.id) }
    project.timeline.tracks[track].add(joined)
  }

}
