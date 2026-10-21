/// How a layer mask joins the masks before it.
public enum MaskMode: String, Codable, CaseIterable, Sendable {
  /// Shows the layer inside it too.
  case add
  /// Hides the layer inside it.
  case subtract
}
