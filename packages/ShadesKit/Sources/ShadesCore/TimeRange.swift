/// A stretch of time from `start` up to (not including) `end`.
public struct TimeRange: Codable, Hashable, Sendable {
  public init(start: MediaTime, end: MediaTime) {
    self.start = start
    self.end = end
  }

  public var start: MediaTime
  public var end: MediaTime

  public var duration: MediaTime {
    end - start
  }

  /// Whether the two ranges share any time.
  public func overlaps(_ other: TimeRange) -> Bool {
    start < other.end && other.start < end
  }
}
