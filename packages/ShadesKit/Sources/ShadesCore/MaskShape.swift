/// The outline of a layer mask.
public enum MaskShape: String, Codable, CaseIterable, Sendable {
  case rectangle
  case ellipse
  /// A free outline through points (a polygon, or a bezier followed in short steps).
  case path
}
