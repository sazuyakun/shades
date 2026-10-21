/// A level at a moment: one point of a gain envelope, which runs in straight lines between its
/// points.
public struct GainPoint: Codable, Hashable, Sendable {
  public init(time: MediaTime, gain: Double) {
    self.time = time
    self.gain = gain
  }

  public var time: MediaTime
  /// Linear gain: 1 unchanged, 0.5 about 6 dB quieter.
  public var gain: Double
}
