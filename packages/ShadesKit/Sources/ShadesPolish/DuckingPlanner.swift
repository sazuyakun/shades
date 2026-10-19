import ShadesCore

/// Plans music ducking: the music dips while someone speaks and comes back up between. Ported
/// from Nebula.
public enum DuckingPlanner {

  // MARK: Public

  /// When someone is heard speaking on the timeline: speech in the clips of every track but
  /// `music`, merged.
  public static func speech(
    in timeline: Timeline,
    except music: Int,
    analyses: [Media.ID: MediaAnalysis],
  ) -> [TimeRange] {
    let ranges = timeline.tracks.indices.filter { $0 != music }
      .flatMap { PolishPlanner.speechOnTimeline(timeline.tracks[$0], analyses: analyses) }
    return merged(ranges)
  }

  // MARK: Internal

  /// The music's gain from `start` to `end` as points (timeline time, gain): 1 away from speech,
  /// `duckTo` during it, ramping down over `attack` before speech and up over `release` after.
  /// Speech close enough that the ramps would meet stays ducked between.
  static func envelope(
    speech: [TimeRange],
    from start: MediaTime,
    to end: MediaTime,
    duckTo: Double,
    attack: Double,
    release: Double,
  ) -> [(time: MediaTime, gain: Double)] {
    let clipped = merged(speech.compactMap { range -> TimeRange? in
      let from = max(range.start, start)
      let to = min(range.end, end)
      return from < to ? TimeRange(start: from, end: to) : nil
    })
    var regions = [TimeRange]()
    for range in clipped {
      if let last = regions.last, (range.start - last.end).seconds <= attack + release {
        regions[regions.count - 1].end = max(last.end, range.end)
      } else {
        regions.append(range)
      }
    }
    guard duckTo < 1, !regions.isEmpty else {
      return []
    }
    var points = [(time: MediaTime, gain: Double)]()
    for region in regions {
      let rampStart = region.start - MediaTime(seconds: attack)
      if rampStart > start {
        if points.isEmpty {
          points.append((start, 1))
        }
        points.append((rampStart, 1))
      } else if points.isEmpty {
        let progress = attack > 0 ? (start - rampStart).seconds / attack : 1
        points.append((start, 1 + (duckTo - 1) * progress))
      }
      points.append((region.start, duckTo))
      points.append((region.end, duckTo))
      guard region.end < end else {
        continue
      }
      let rampEnd = region.end + MediaTime(seconds: release)
      if rampEnd <= end {
        points.append((rampEnd, 1))
      } else {
        points.append((end, duckTo + (1 - duckTo) * (end - region.end).seconds / release))
      }
    }
    return points
  }

  // MARK: Private

  /// Ranges sorted, with overlapping or touching ones joined.
  private static func merged(_ ranges: [TimeRange]) -> [TimeRange] {
    var result = [TimeRange]()
    for range in ranges.sorted(by: { $0.start < $1.start }) {
      if let last = result.last, range.start <= last.end {
        result[result.count - 1].end = max(last.end, range.end)
      } else {
        result.append(range)
      }
    }
    return result
  }

}
