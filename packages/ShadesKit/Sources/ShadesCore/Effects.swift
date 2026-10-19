// MARK: - Effects

/// A clip's film-look and keying effects. Every field starts off.
public struct Effects: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    grain: Double = 0,
    vignette: Double = 0,
    halation: Double = 0,
    blur: Double = 0,
    key: ChromaKey? = nil,
  ) {
    self.grain = grain
    self.vignette = vignette
    self.halation = halation
    self.blur = blur
    self.key = key
  }

  // MARK: Public

  /// Film grain, 0 to 1.
  public var grain: Double
  /// Darkened corners, 0 to 1.
  public var vignette: Double
  /// A warm red glow bleeding around bright highlights, as on film, 0 to 1.
  public var halation: Double
  /// Softness, 0 to 1.
  public var blur: Double
  /// Removes a background colour (green screen).
  public var key: ChromaKey?

}

// MARK: Codable

extension Effects: Codable {

  // MARK: Lifecycle

  /// Reads effects where any may be left out (off).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      grain: container.decodeIfPresent(Double.self, forKey: .grain) ?? 0,
      vignette: container.decodeIfPresent(Double.self, forKey: .vignette) ?? 0,
      halation: container.decodeIfPresent(Double.self, forKey: .halation) ?? 0,
      blur: container.decodeIfPresent(Double.self, forKey: .blur) ?? 0,
      key: container.decodeIfPresent(ChromaKey.self, forKey: .key),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case grain
    case vignette
    case halation
    case blur
    case key
  }

}
