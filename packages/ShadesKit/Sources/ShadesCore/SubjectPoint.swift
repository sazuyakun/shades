/// Where the subject's centre is at a moment of a media file, as fractions of its upright picture
/// (0,0 top left; 1,1 bottom right).
public struct SubjectPoint: Codable, Hashable, Sendable {
  public init(time: MediaTime, x: Double, y: Double) {
    self.time = time
    self.x = x
    self.y = y
  }

  public var time: MediaTime
  public var x: Double
  public var y: Double
}
