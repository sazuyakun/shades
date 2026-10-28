/// Where a mix's master limiter and track pan are applied.
public enum AudioShaping: Sendable {
  /// In audio taps, sample by sample: exports, where they're exact.
  case exact
  /// For the player: the limiter as part of each track's volume (close enough to hear), and a tap
  /// only on a panned track. Why: AVPlayer with audio taps can stall on a seek after a pause,
  /// and froze when a tapped track changed format.
  case preview
  /// Neither: the caller shapes the samples itself (`MixReader`).
  case unshaped
}
