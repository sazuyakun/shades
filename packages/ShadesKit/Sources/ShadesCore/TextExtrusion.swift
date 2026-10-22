// MARK: - TextExtrusion

/// Solid 3D letters: the text pushed back into depth, its front edges cut to a slope, lit from
/// above left as it turns in 3D.
public struct TextExtrusion: Hashable, Sendable {

  // MARK: Lifecycle

  public init(depth: Double = 0.3, bevel: Double = 0.03) {
    self.depth = depth
    self.bevel = bevel
  }

  // MARK: Public

  /// How deep the letters go, as a fraction of the size.
  public var depth: Double
  /// How far the slope round the front edges reaches in, as a fraction of the size; 0 is a
  /// sharp edge.
  public var bevel: Double

}

// MARK: Codable

extension TextExtrusion: Codable {

  // MARK: Lifecycle

  /// Reads an extrusion where either field may be left out (it keeps its default).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = TextExtrusion()
    try self.init(
      depth: container.decodeIfPresent(Double.self, forKey: .depth) ?? base.depth,
      bevel: container.decodeIfPresent(Double.self, forKey: .bevel) ?? base.bevel,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case depth
    case bevel
  }

}
