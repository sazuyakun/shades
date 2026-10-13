import Foundation

// MARK: - MediaTime

/// An exact point or length of time, stored as a fraction of a second (`value / timescale`).
public struct MediaTime: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(value: Int64, timescale: Int32) {
    self.value = value
    self.timescale = timescale
  }

  /// Rounds `seconds` to the nearest unit of `timescale`.
  public init(seconds: Double, timescale: Int32 = 600) {
    self.init(value: Int64((seconds * Double(timescale)).rounded()), timescale: timescale)
  }

  // MARK: Public

  public static let zero = MediaTime(value: 0, timescale: 600)

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

  // MARK: Private

  private static func leastCommonMultiple(_ a: Int32, _ b: Int32) -> Int32 {
    var x = a
    var y = b
    while y != 0 {
      (x, y) = (y, x % y)
    }
    return a / x * b
  }

  private func rescaled(to timescale: Int32) -> Int64 {
    value * Int64(timescale / self.timescale)
  }

}

// MARK: Comparable

extension MediaTime: Comparable {
  public static func <(lhs: MediaTime, rhs: MediaTime) -> Bool {
    Int128(lhs.value) * Int128(rhs.timescale) < Int128(rhs.value) * Int128(lhs.timescale)
  }
}
