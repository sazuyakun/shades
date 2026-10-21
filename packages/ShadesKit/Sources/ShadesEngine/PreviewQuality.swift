/// How big playback frames are drawn. Exports and frames for Claude are always full size.
public enum PreviewQuality: CaseIterable, Sendable {
  /// Full size, dropping to half while playing once frames can't keep up.
  case auto
  case full
  /// Half the width and height: a quarter of the pixels, for heavy timelines.
  case half
}
