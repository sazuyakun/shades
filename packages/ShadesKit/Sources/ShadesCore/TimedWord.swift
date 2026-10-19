/// One word of a text clip and when it's said, in the clip's source time.
public struct TimedWord: Codable, Hashable, Sendable {
  public init(text: String, start: MediaTime, end: MediaTime) {
    self.text = text
    self.start = start
    self.end = end
  }

  public var text: String
  public var start: MediaTime
  public var end: MediaTime
}
