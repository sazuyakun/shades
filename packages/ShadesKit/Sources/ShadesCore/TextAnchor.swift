/// Where text sits in the frame before the clip's position moves it.
public enum TextAnchor: String, Codable, CaseIterable, Sendable {
  /// Near the bottom, like a caption.
  case bottom
  /// In the middle, like a title.
  case center
}
