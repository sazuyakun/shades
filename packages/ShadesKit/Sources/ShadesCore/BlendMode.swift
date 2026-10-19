/// How a layer mixes with what's under it.
public enum BlendMode: String, Codable, CaseIterable, Sendable {
  case normal
  /// Brightens: good for flares, sparks and light leaks on black.
  case add
  /// Brightens more gently than add: overlays on black.
  case screen
  /// Darkens: overlays on white or paper.
  case multiply
  /// Adds contrast and texture: grain and texture plates on grey.
  case overlay
  /// A gentler overlay.
  case softLight
  /// Keeps the lighter of the two.
  case lighten
  /// Keeps the darker of the two.
  case darken
}
