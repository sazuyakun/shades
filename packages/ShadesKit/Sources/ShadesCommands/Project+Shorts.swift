import ShadesCore

/// What every short edit shares: finding a short and checking its stretch.
extension Project {

  /// Where the short is in the timeline's list.
  func requireShort(_ id: Short.ID) throws(CommandError) -> Int {
    guard let index = timeline.shorts.firstIndex(where: { $0.id == id }) else {
      throw rejected(.shortNotFound(id))
    }
    return index
  }

  /// `start` to `end` snapped to frames, checked to make a short inside the timeline.
  func shortRange(from start: MediaTime, to end: MediaTime) throws(CommandError) -> TimeRange {
    let range = TimeRange(start: onFrame(start), end: onFrame(end))
    guard range.start >= .zero, range.end > range.start else {
      throw rejected(.invalidRange("a short needs an end after its start"))
    }
    guard range.end <= timeline.duration else {
      throw rejected(.invalidRange("the short ends after the timeline does"))
    }
    return range
  }

}
