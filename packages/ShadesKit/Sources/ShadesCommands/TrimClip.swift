import ShadesCore

/// Moves a clip's start and/or end edge. With ripple, later clips on the track follow the edit;
/// without it, the gap stays or the clip needs empty room to grow into.
public struct TrimClip: ToolCommand {

  // MARK: Lifecycle

  public init(
    clipID: Clip.ID,
    start: MediaTime? = nil,
    end: MediaTime? = nil,
    ripple: Bool? = nil,
  ) {
    self.clipID = clipID
    self.start = start
    self.end = end
    self.ripple = ripple
  }

  // MARK: Public

  public static let title = "Trim Clip"
  public static let name = "trim_clip"
  public static let summary = "Move a clip's start and/or end edge to a time on the timeline. "
    + "With ripple, trimming the start keeps the clip where it begins and later clips follow; "
    + "trimming the end moves later clips with the end."
  public static let parameters = JSONSchema.object(
    [
      "clip_id": Fields.clipID,
      "start": Fields.time("New start edge"),
      "end": Fields.time("New end edge"),
      "ripple": Fields.ripple,
    ],
    required: ["clip_id"],
  )

  public let clipID: Clip.ID
  public let start: MediaTime?
  public let end: MediaTime?
  public let ripple: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    // why: the end goes first because trimming it never moves the clip's start.
    if let end {
      try trimEnd(to: project.onFrame(end), in: &project)
    }
    if let start {
      try trimStart(to: project.onFrame(start), in: &project)
    }
  }

  // MARK: Private

  private func trimEnd(to time: MediaTime, in project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    let trimmed = clip.trimmingEnd(to: time)
    try check(trimmed, in: project)
    var track = project.timeline.tracks[location.track]
    track.clips.remove(at: location.clip)
    if ripple == true {
      track.shift(from: clip.timelineEnd, by: time - clip.timelineEnd)
    } else if !track.isClear(from: trimmed.timelineStart, to: trimmed.timelineEnd) {
      throw rejected(.noRoom("another clip is in the way; trim with ripple to push it"))
    }
    track.add(trimmed)
    project.timeline.tracks[location.track] = track
  }

  private func trimStart(to time: MediaTime, in project: inout Project) throws(CommandError) {
    let location = try project.requireClip(clipID)
    let clip = project.timeline.tracks[location.track].clips[location.clip]
    var trimmed = clip.trimmingStart(to: time)
    try check(trimmed, in: project)
    var track = project.timeline.tracks[location.track]
    track.clips.remove(at: location.clip)
    if ripple == true {
      trimmed.timelineStart = clip.timelineStart
      track.shift(from: clip.timelineEnd, by: trimmed.timelineEnd - clip.timelineEnd)
    } else if !track.isClear(from: trimmed.timelineStart, to: trimmed.timelineEnd) {
      throw rejected(.noRoom("another clip is in the way; trim with ripple to push it"))
    }
    track.add(trimmed)
    project.timeline.tracks[location.track] = track
  }

  /// Rejects a trim that leaves nothing or reaches past either end of the media (text, still
  /// and freeze-frame clips can be any length).
  private func check(_ clip: Clip, in project: Project) throws(CommandError) {
    guard clip.duration > .zero, clip.timelineStart >= .zero else {
      throw rejected(.invalidRange("the clip would have no length left"))
    }
    guard let mediaID = clip.mediaID, !clip.isFrozen else {
      return
    }
    let media = try project.requireMedia(mediaID)
    guard !media.isStill else {
      return
    }
    let available = media.duration.flooredToFrame(at: project.timeline.format.framesPerSecond)
    guard
      clip.sourceStart >= .zero, clip.sourceEnd <= available,
      clip.timelineStart >= .zero
    else {
      throw rejected(.invalidRange("the clip can't extend past the start or end of its media"))
    }
  }

}
