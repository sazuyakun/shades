/// A speech model that transcribes on this Mac. The raw value is its folder name in the model
/// repository (shared with Nebula, so a model downloaded by either app works for both).
public enum TranscriptionModel: String, CaseIterable, Sendable, Codable {
  /// Smallest and fastest; good for clear speech.
  case base = "openai_whisper-base"
  /// Balanced speed and accuracy; the default.
  case small = "openai_whisper-small"
  /// Most accurate (best for mixed Hindi and English), slower and 1.6 GB.
  case largeTurbo = "openai_whisper-large-v3-v20240930_turbo"

  /// The name shown to people.
  public var title: String {
    switch self {
    case .base: "Base"
    case .small: "Small"
    case .largeTurbo: "Large Turbo"
    }
  }
}
