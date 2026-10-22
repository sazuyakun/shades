import ShadesCore

/// Cuts stretches of time out of a track: silences, fillers, unwanted words. With ripple, later
/// clips on the track close up. Tracks holding clips linked to the cut ones (a video's detached
/// sound) are cut the same way, so they stay in step.
public struct RemoveRanges: ToolCommand {

  // MARK: Lifecycle

  public init(
    ranges: [TimeRange],
    track: String? = nil,
    ripple: Bool? = nil,
    allTracks: Bool? = nil,
  ) {
    self.ranges = ranges
    self.track = track
    self.ripple = ripple
    self.allTracks = allTracks
  }

  // MARK: Public

  public static let title = "Remove Ranges"
  public static let name = "remove_ranges"
  public static let summary = "Cut stretches of time out of a track (V1 by default), like "
    + "silences or unwanted words from get_transcript. With ripple (default true) the track closes "
    + "up. Linked clips (a video's detached sound) are cut with it; other tracks only follow "
    + "with all_tracks."
  public static let parameters = JSONSchema.object(
    [
      "ranges": JSONSchema.array(
        "Stretches to cut, in timeline seconds",
        items: JSONSchema.object(
          [
            "start": JSONSchema.number("Start, in seconds"),
            "end": JSONSchema.number("End, in seconds"),
          ],
          required: ["start", "end"],
        ),
      ),
      "track": Fields.track,
      "ripple": Fields.ripple,
      "all_tracks": JSONSchema.boolean(
        "Cut the same time from every video and text track too, keeping B-roll and captions in "
          + "sync (music on audio tracks keeps playing). Default false"
      ),
    ],
    required: ["ranges"],
  )

  public let ranges: [TimeRange]
  public let track: String?
  public let ripple: Bool?
  public let allTracks: Bool?

  public func apply(to project: inout Project) throws(CommandError) {
    let main = try track.map(project.requireTrack) ?? project.timeline.tracks
      .firstIndex { $0.kind == .video } ?? 0
    let indices = project.linkedTracks(allTracks == true
      ? project.timeline.tracks.indices
        .filter { $0 == main || project.timeline.tracks[$0].kind != .audio }
      : [main])
    let cuts = merged(ranges.map { TimeRange(
      start: project.onFrame($0.start),
      end: project.onFrame($0.end),
    ) })
    guard !cuts.isEmpty else {
      throw rejected(.invalidRange("give at least one range whose end comes after its start"))
    }
    // why: cutting from the end backwards keeps earlier ranges' times valid as the track closes.
    for cut in cuts.reversed() {
      for index in indices {
        project.timeline.tracks[index].clear(from: cut.start, to: cut.end)
        if ripple ?? true {
          project.timeline.tracks[index].shift(from: cut.end, by: .zero - cut.duration)
        }
      }
    }
  }

  // MARK: Private

  /// Ranges sorted, with overlapping or touching ones joined and empty ones dropped.
  private func merged(_ ranges: [TimeRange]) -> [TimeRange] {
    var result = [TimeRange]()
    for range in ranges.filter({ $0.end > $0.start }).sorted(by: { $0.start < $1.start }) {
      if let last = result.last, range.start <= last.end {
        result[result.count - 1].end = max(last.end, range.end)
      } else {
        result.append(range)
      }
    }
    return result
  }

}
