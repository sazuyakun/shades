import Foundation

// MARK: - MediaTime

/// An exact point or length of time, stored as a fraction of a second (`value / timescale`).
/// Timeline times use `timelineTimescale`, which divides evenly into every frame rate Shades
/// offers, so frame boundaries are exact.
public struct MediaTime: Sendable {

  // MARK: Lifecycle

  public init(value: Int64, timescale: Int32) {
    self.value = value
    self.timescale = timescale
  }

  /// Rounds `seconds` to the nearest unit of `timescale`.
  public init(seconds: Double, timescale: Int32 = timelineTimescale) {
    self.init(value: Int64((seconds * Double(timescale)).rounded()), timescale: timescale)
  }

  // MARK: Public

  /// 600 units per second: a whole number of units per frame at 24, 30 and 60 fps.
  public static let timelineTimescale: Int32 = 600

  public static let zero = MediaTime(value: 0, timescale: timelineTimescale)

  public let value: Int64
  public let timescale: Int32

  /// The time in seconds, for display and for APIs that take seconds.
  public var seconds: Double {
    Double(value) / Double(timescale)
  }

  public static func +(lhs: MediaTime, rhs: MediaTime) -> MediaTime {
    let timescale = leastCommonMultiple(lhs.timescale, rhs.timescale)
    return MediaTime(
      value: lhs.rescaled(to: timescale) + rhs.rescaled(to: timescale),
      timescale: timescale,
    )
  }

  public static func -(lhs: MediaTime, rhs: MediaTime) -> MediaTime {
    let timescale = leastCommonMultiple(lhs.timescale, rhs.timescale)
    return MediaTime(
      value: lhs.rescaled(to: timescale) - rhs.rescaled(to: timescale),
      timescale: timescale,
    )
  }

  /// The nearest frame boundary at `framesPerSecond` (which must divide 600), in the timeline
  /// timescale.
  public func roundedToFrame(at framesPerSecond: Int) -> MediaTime {
    let unitsPerFrame = Int64(Self.timelineTimescale) / Int64(framesPerSecond)
    let frames = (seconds * Double(framesPerSecond)).rounded()
    return MediaTime(value: Int64(frames) * unitsPerFrame, timescale: Self.timelineTimescale)
  }

  // MARK: Private

  private static func leastCommonMultiple(_ a: Int32, _ b: Int32) -> Int32 {
    a / Int32(greatestCommonDivisor(Int64(a), Int64(b))) * b
  }

  private static func greatestCommonDivisor(_ a: Int64, _ b: Int64) -> Int64 {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
      (x, y) = (y, x % y)
    }
    return x
  }

  private func rescaled(to timescale: Int32) -> Int64 {
    value * Int64(timescale / self.timescale)
  }

}

// MARK: Hashable

extension MediaTime: Hashable {
  /// Equal when they're the same length of time, whatever their timescales (1/2 == 300/600).
  public static func ==(lhs: MediaTime, rhs: MediaTime) -> Bool {
    Int128(lhs.value) * Int128(rhs.timescale) == Int128(rhs.value) * Int128(lhs.timescale)
  }

  public func hash(into hasher: inout Hasher) {
    let divisor = Swift.max(Self.greatestCommonDivisor(value, Int64(timescale)), 1)
    hasher.combine(value / divisor)
    hasher.combine(Int64(timescale) / divisor)
  }
}

// MARK: Comparable

extension MediaTime: Comparable {
  public static func <(lhs: MediaTime, rhs: MediaTime) -> Bool {
    Int128(lhs.value) * Int128(rhs.timescale) < Int128(rhs.value) * Int128(lhs.timescale)
  }
}

// MARK: Codable

extension MediaTime: Codable {

  // MARK: Lifecycle

  /// Reads either an exact `{"value", "timescale"}` object (project files) or a plain number of
  /// seconds (what Claude sends).
  public init(from decoder: any Decoder) throws {
    if let seconds = try? decoder.singleValueContainer().decode(Double.self) {
      self.init(seconds: seconds)
      return
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      value: container.decode(Int64.self, forKey: .value),
      timescale: container.decode(Int32.self, forKey: .timescale),
    )
  }

  // MARK: Public

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(value, forKey: .value)
    try container.encode(timescale, forKey: .timescale)
  }

  // MARK: Private

  private enum CodingKeys: String, CodingKey {
    case value
    case timescale
  }

}
