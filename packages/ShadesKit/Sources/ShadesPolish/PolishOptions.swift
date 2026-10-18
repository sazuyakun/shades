/// What Polish looks for, and how fussy it is.
public struct PolishOptions: Sendable, Hashable, Codable {

  // MARK: Lifecycle

  public init(
    silences: Bool = true,
    fillers: Bool = true,
    retakes: Bool = true,
    beatSnap: Bool = true,
    punchIn: Bool = true,
    minimumSilence: Double = 0.6,
    padding: Double = 0.12,
  ) {
    self.silences = silences
    self.fillers = fillers
    self.retakes = retakes
    self.beatSnap = beatSnap
    self.punchIn = punchIn
    self.minimumSilence = minimumSilence
    self.padding = padding
  }

  // MARK: Public

  /// Words cut as fillers, compared lowercased without punctuation. Includes Hindi "matlab".
  public static let fillerWords: Set = [
    "um",
    "umm",
    "uh",
    "uhh",
    "uhm",
    "erm",
    "er",
    "ah",
    "hmm",
    "mm",
    "matlab",
  ]

  public var silences: Bool
  public var fillers: Bool
  public var retakes: Bool
  public var beatSnap: Bool
  public var punchIn: Bool
  /// Pauses shorter than this (seconds) are left alone.
  public var minimumSilence: Double
  /// Breathing room (seconds) kept around words when cutting a pause.
  public var padding: Double

}
