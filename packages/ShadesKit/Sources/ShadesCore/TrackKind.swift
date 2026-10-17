/// What a track holds: pictures (with their own sound) or sound only.
public enum TrackKind: String, Codable, Sendable {
  case video
  case audio
}
