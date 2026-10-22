import ShadesCommands
import ShadesCore

/// Applies the switched-on items of a Polish plan as one edit: the cuts (moved onto beats where
/// a snap is on) close up the timeline, B-roll, captions and linked sound included (music keeps
/// playing), punch-ins zoom every second stretch, noisy sound switches to its cleaned copy, the
/// music ducks under the speech where it now lands, and last the loudness is set.
public struct ApplyPolish: Command {

  // MARK: Lifecycle

  /// Applies `plan`; `loudness` is the level and limiter measured on the polished mix, used when
  /// the plan's loudness item is on.
  public init(plan: PolishPlan, loudness: NormalizeLoudness? = nil) {
    self.plan = plan
    self.loudness = loudness
  }

  // MARK: Public

  public static let title = "Polish"

  public let plan: PolishPlan
  public let loudness: NormalizeLoudness?

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
      try RemoveRanges(ranges: cuts, track: plan.track, ripple: true, allTracks: true)
        .apply(to: &project)
    }
    let zooms = enabled.filter { $0.kind == .punchIn }.map { stretch in
      TimeRange(
        start: closedUp(stretch.range.start, cuts: cuts),
        end: closedUp(stretch.range.end, cuts: cuts),
      )
    }
    if
      !zooms.isEmpty,
      let track = project.timeline.tracks
        .firstIndex(where: { project.timeline.label(of: $0) == plan.track })
    {
      for index in project.timeline.tracks[track].clips.indices {
        let clip = project.timeline.tracks[track].clips[index]
        let middle = clip.timelineStart + MediaTime(seconds: clip.duration.seconds / 2)
        if zooms.contains(where: { $0.start <= middle && middle < $0.end }) {
          project.timeline.tracks[track].clips[index].transform.scale = clip.transform
            .scale * PolishPlanner.punchInScale
        }
      }
    }
    clean(Set(enabled.filter { $0.kind == .noise }.compactMap(\.media)), in: &project)
    if enabled.contains(where: { $0.kind == .duck }) {
      try duck(in: &project)
    }
    if enabled.contains(where: { $0.kind == .loudness }), let loudness {
      try loudness.apply(to: &project)
    }
  }

  // MARK: Private

  /// Sets every clip playing the sound of `media` to play its cleaned copy.
  private func clean(_ media: Set<Media.ID>, in project: inout Project) {
    for track in project.timeline.tracks.indices {
      let kind = project.timeline.tracks[track].kind
      for index in project.timeline.tracks[track].clips.indices {
        let clip = project.timeline.tracks[track].clips[index]
        if let id = clip.mediaID, media.contains(id), kind == .audio || clip.isAudioEnabled {
          project.timeline.tracks[track].clips[index].cleanSound = true
        }
      }
    }
  }

  /// Ducks the plan's music track under the speech as it falls after the cuts.
  private func duck(in project: inout Project) throws(CommandError) {
    let timeline = project.timeline
    guard
      let music = plan.music.flatMap({ label in
        timeline.tracks.firstIndex { timeline.label(of: $0) == label }
      })
    else {
      return
    }
    let speech = DuckingPlanner.speech(
      in: timeline,
      except: music,
      analyses: plan.speech.mapValues { MediaAnalysis(speech: $0) },
    )
    guard !speech.isEmpty else {
      return
    }
    try DuckMusic(track: music, speech: speech, duckTo: plan.duckLevel).apply(to: &project)
  }

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
