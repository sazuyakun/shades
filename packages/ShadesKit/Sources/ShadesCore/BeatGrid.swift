/// The beats of a piece of music: its tempo and when each beat falls, in the file's time.
public struct BeatGrid: Codable, Hashable, Sendable {
  public init(beatsPerMinute: Double, beats: [MediaTime]) {
    self.beatsPerMinute = beatsPerMinute
    self.beats = beats
  }

  public var beatsPerMinute: Double
  public var beats: [MediaTime]
}
