/// What finds the subject in each frame.
public enum MatteEngine: String, CaseIterable, Sendable, Codable {
  /// Apple Vision's person segmentation (people only), at its most accurate setting.
  case visionPerson
  /// Apple Vision's foreground mask: whatever stands out, people or objects.
  case visionForeground

  /// The name shown to people and Claude.
  public var title: String {
    switch self {
    case .visionPerson: "Person (Apple Vision)"
    case .visionForeground: "Any subject (Apple Vision)"
    }
  }
}
