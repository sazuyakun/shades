import ShadesCore

/// Joins neighbouring pieces of the same media back into one clip, undoing splits, and their
/// linked clips' pieces too where those join.
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
    guard Self.isContinuous(clips) else {
      throw rejected(.cannotJoin("they must be back to back pieces of the same media"))
    }
    let partners = Dictionary(grouping: clips.flatMap { project.timeline.partners(of: $0.id) }) {
      project.timeline.location(ofClip: $0.id)?.track
    }
    Self.join(clips, on: track, in: &project)
    // why: linked pieces that aren't back to back (one was slipped) just stay as they are.
    for case (let track?, let pieces) in partners where Self.isContinuous(pieces) {
      Self.join(pieces, on: track, in: &project)
    }
  }

  // MARK: Private

  /// Whether `clips` are back to back pieces of the same media, playing at the same speed.
  private static func isContinuous(_ clips: [Clip]) -> Bool {
    let sorted = clips.sorted { $0.timelineStart < $1.timelineStart }
    return sorted.count >= 2 && zip(sorted, sorted.dropFirst()).allSatisfy { left, right in
      left.mediaID == right.mediaID && left.timelineEnd == right.timelineStart
        && left.sourceEnd == right.sourceStart && left.speed == right.speed
        && left.keyframes.filter { $0.property == .speed }
        == right.keyframes.filter { $0.property == .speed }
    }
  }

  /// Replaces `clips` on `track` with one clip from the first one's start to the last one's end.
  private static func join(_ clips: [Clip], on track: Int, in project: inout Project) {
    let sorted = clips.sorted { $0.timelineStart < $1.timelineStart }
    guard var joined = sorted.first, let last = sorted.last else {
      return
    }
    joined.duration = last.timelineEnd - joined.timelineStart
    let removed = Set(clips.map(\.id))
    project.timeline.tracks[track].clips.removeAll { removed.contains($0.id) }
    project.timeline.tracks[track].add(joined)
  }

}
