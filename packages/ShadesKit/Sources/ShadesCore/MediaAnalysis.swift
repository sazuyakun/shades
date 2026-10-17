/// What Shades has worked out about one media file, kept so it never has to be redone.
public struct MediaAnalysis: Codable, Hashable, Sendable {
  public init(transcript: Transcript? = nil, speech: [TimeRange]? = nil, beats: BeatGrid? = nil) {
    self.transcript = transcript
    self.speech = speech
    self.beats = beats
  }

  /// What was said, with word timings.
  public var transcript: Transcript?
  /// When someone is talking.
  public var speech: [TimeRange]?
  /// The music's beats.
  public var beats: BeatGrid?
}
