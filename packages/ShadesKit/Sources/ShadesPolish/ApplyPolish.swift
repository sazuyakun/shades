import ShadesCommands
import ShadesCore

/// Applies the switched-on items of a Polish plan as one edit: the cuts (moved onto beats where
/// a snap is on) close up the track, then punch-ins zoom every second stretch.
public struct ApplyPolish: Command {

  // MARK: Lifecycle

  public init(plan: PolishPlan) {
    self.plan = plan
  }

  // MARK: Public

  public static let title = "Polish"

  public let plan: PolishPlan

  public func apply(to project: inout Project) throws(CommandError) {
    let fps = project.timeline.format.framesPerSecond
    let enabled = plan.items.filter(\.isEnabled)
    let snaps = enabled.filter { $0.kind == .beatSnap }
    // why: cuts and stretches go onto frames once, here, so the punch-ins below line up exactly
    // with the clip edges the cuts leave.
    let cuts = enabled.filter(\.kind.isCut).map { cut in
      onFrames(snaps.first { $0.range.end == cut.range.end }?.range ?? cut.range, fps: fps)
    }
    if !cuts.isEmpty {
      try RemoveRanges(ranges: cuts, track: plan.track, ripple: true).apply(to: &project)
    }
    let zooms = enabled.filter { $0.kind == .punchIn }.map { stretch in
      TimeRange(
        start: closedUp(stretch.range.start, cuts: cuts),
        end: closedUp(stretch.range.end, cuts: cuts),
      )
    }
    guard
      !zooms.isEmpty,
      let track = project.timeline.tracks
        .firstIndex(where: { project.timeline.label(of: $0) == plan.track })
    else {
      return
    }
    for index in project.timeline.tracks[track].clips.indices {
      let clip = project.timeline.tracks[track].clips[index]
      let middle = clip.timelineStart + MediaTime(seconds: clip.duration.seconds / 2)
      if zooms.contains(where: { $0.start <= middle && middle < $0.end }) {
        project.timeline.tracks[track].clips[index].transform.scale = clip.transform
          .scale * PolishPlanner.punchInScale
      }
    }
  }

  // MARK: Private

  private func onFrames(_ range: TimeRange, fps: Int) -> TimeRange {
    TimeRange(start: range.start.roundedToFrame(at: fps), end: range.end.roundedToFrame(at: fps))
  }

  /// Where `time` lands once `cuts` are removed and the track closes up.
  private func closedUp(_ time: MediaTime, cuts: [TimeRange]) -> MediaTime {
    let removed = cuts.filter { $0.start < time }.reduce(MediaTime.zero) { total, cut in
      total + (min(cut.end, time) - cut.start)
    }
    return time - removed
  }

}
