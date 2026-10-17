/// What a track holds: pictures (with their own sound), sound only, or text (captions and
/// titles, drawn above the video).
public enum TrackKind: String, Codable, Sendable {
  case video
  case audio
  case text
}
