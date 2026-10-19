// MARK: - ChromaKey

/// Makes one colour see-through, like a green screen.
public struct ChromaKey: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    color: HexColor = HexColor(red: 0, green: 1, blue: 0),
    tolerance: Double = 0.3,
    softness: Double = 0.1,
  ) {
    self.color = color
    self.tolerance = tolerance
    self.softness = softness
  }

  // MARK: Public

  public var color: HexColor
  /// How far from the colour still counts as background, 0 to 1.
  public var tolerance: Double
  /// How gradually the edge fades, 0 to 1.
  public var softness: Double

}

// MARK: Codable

extension ChromaKey: Codable {

  // MARK: Lifecycle

  /// Reads a key where any field may be left out (green, with a moderate tolerance).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = ChromaKey()
    try self.init(
      color: container.decodeIfPresent(HexColor.self, forKey: .color) ?? base.color,
      tolerance: container.decodeIfPresent(Double.self, forKey: .tolerance) ?? base.tolerance,
      softness: container.decodeIfPresent(Double.self, forKey: .softness) ?? base.softness,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case color
    case tolerance
    case softness
  }

}
