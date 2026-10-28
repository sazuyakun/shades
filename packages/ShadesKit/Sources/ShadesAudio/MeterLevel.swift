/// A meter's reading: the loudest sample of each channel, as linear levels (1 is full scale).
public struct MeterLevel: Hashable, Sendable {
  public init(left: Double, right: Double) {
    self.left = left
    self.right = right
  }

  public let left: Double
  public let right: Double
}
