/// What Shades has worked out about one media file, kept so it never has to be redone.
public struct MediaAnalysis: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    transcript: Transcript? = nil,
    speech: [TimeRange]? = nil,
    beats: BeatGrid? = nil,
    matte: String? = nil,
    subjectPath: [SubjectPoint]? = nil,
    tracks: [String: [SubjectPoint]]? = nil,
    cleanSound: String? = nil,
  ) {
    self.transcript = transcript
    self.speech = speech
    self.beats = beats
    self.matte = matte
    self.subjectPath = subjectPath
    self.tracks = tracks
    self.cleanSound = cleanSound
  }

  // MARK: Public

  /// What was said, with word timings.
  public var transcript: Transcript?
  /// When someone is talking.
  public var speech: [TimeRange]?
  /// The music's beats.
  public var beats: BeatGrid?
  /// The cut-out's file name in the project's `cache/mattes` folder.
  public var matte: String?
  /// Where the subject is over time, from the cut-out.
  public var subjectPath: [SubjectPoint]?
  /// Things followed through the picture with `track_motion`, by the name they were given.
  public var tracks: [String: [SubjectPoint]]?
  /// The noise-reduced sound's file name in the project's `cache/sound` folder.
  public var cleanSound: String?

}
