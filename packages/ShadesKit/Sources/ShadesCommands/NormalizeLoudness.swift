import ShadesCore

/// Sets the whole mix's level and the master limiter together, as worked out by measuring the
/// mix for a loudness target.
public struct NormalizeLoudness: Command {

  // MARK: Lifecycle

  public init(gain: Double, limiter: [GainPoint]) {
    self.gain = gain
    self.limiter = limiter
  }

  // MARK: Public

  public static let title = "Normalize Loudness"

  public let gain: Double
  /// The limiter's gain over the timeline, every point from 0 to 1.
  public let limiter: [GainPoint]

  public func apply(to project: inout Project) throws(CommandError) {
    guard (0 ... 8).contains(gain) else {
      throw rejected(.invalidValue("the master level goes from 0 to 8"))
    }
    guard limiter.allSatisfy({ (0 ... 1).contains($0.gain) }) else {
      throw rejected(.invalidValue("the limiter only turns the sound down, from 0 to 1"))
    }
    project.timeline.gain = gain
    project.timeline.limiter = limiter.sorted { $0.time < $1.time }
  }

}
