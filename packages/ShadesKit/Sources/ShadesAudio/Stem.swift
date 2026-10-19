/// A part of a recording that stem separation pulls out on its own.
public enum Stem: String, CaseIterable, Codable, Sendable {
  /// Singing and speech.
  case voice
  /// Everything else: drums, bass and the rest of the music.
  case music
}
