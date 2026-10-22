/// The ways one clip can turn into the next.
public enum TransitionKind: String, Codable, CaseIterable, Sendable {
  /// The two pictures mix.
  case dissolve
  /// Fades to black, then up from black.
  case dipToBlack
  /// A burst of white at the cut.
  case flash
  /// A fast blurred pan from one shot into the next.
  case whip
  /// The next shot pushes the last one out sideways.
  case push
  /// The next shot slides in as horizontal slices, one after another.
  case slices
  /// The next shot appears tile by tile.
  case tiles
  /// The next shot opens from a growing circle in the middle.
  case iris
  /// The view zooms in through a small frame of the next shot in the middle until it fills the
  /// picture.
  case portal
}
