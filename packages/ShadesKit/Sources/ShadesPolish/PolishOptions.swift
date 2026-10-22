import ShadesCore

/// What Polish looks for, and how fussy it is.
public struct PolishOptions: Sendable, Hashable, Codable {

  // MARK: Lifecycle

  public init(
    silences: Bool = true,
    fillers: Bool = true,
    retakes: Bool = true,
    beatSnap: Bool = true,
    punchIn: Bool = true,
    duck: Bool = true,
    noise: Bool = true,
    loudness: LoudnessTarget? = .youtube,
    duckLevel: Double = 0.25,
    minimumSilence: Double = 0.6,
    padding: Double = 0.12,
  ) {
    self.silences = silences
    self.fillers = fillers
    self.retakes = retakes
    self.beatSnap = beatSnap
    self.punchIn = punchIn
    self.duck = duck
    self.noise = noise
    self.loudness = loudness
    self.duckLevel = duckLevel
    self.minimumSilence = minimumSilence
    self.padding = padding
  }

  // MARK: Public

  /// Words cut as fillers, compared lowercased without punctuation. Includes Hindi "matlab" and
  /// Hindi hesitations in Devanagari (हम्म and the rest; हम, "we", is a word, not a filler).
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
    "उम",
    "उम्म",
    "अम",
    "अम्म",
    "अं",
    "आं",
    "उह",
    "अह",
    "हम्म",
    "हम्म्म",
    "मतलब",
  ]

  /// How strongly noise reduction cleans, 0 to 1.
  public static let noiseStrength = 0.7
  /// A background louder than this (dBFS) is worth cleaning.
  public static let noisyFloor = -50.0

  public var silences: Bool
  public var fillers: Bool
  public var retakes: Bool
  public var beatSnap: Bool
  public var punchIn: Bool
  /// Lower the music while anyone speaks.
  public var duck: Bool
  /// Clean noisy backgrounds out of the speech.
  public var noise: Bool
  /// Normalise the mix for this platform, or leave the level alone.
  public var loudness: LoudnessTarget?
  /// The music's level under speech, as a share of its own (0.25 is about 12 dB down).
  public var duckLevel: Double
  /// Pauses shorter than this (seconds) are left alone.
  public var minimumSilence: Double
  /// Breathing room (seconds) kept around words when cutting a pause.
  public var padding: Double

}
