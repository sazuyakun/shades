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
    shader: String? = nil,
    shaderAmount: Double = 1,
    portal: Portal? = nil,
  ) {
    self.grain = grain
    self.vignette = vignette
    self.halation = halation
    self.blur = blur
    self.key = key
    self.shader = shader
    self.shaderAmount = shaderAmount
    self.portal = portal
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
  /// A Metal shader effect: a `.metal` file's path, or a plugin's shader by name.
  public var shader: String?
  /// How strongly the shader effect applies, 0 to 1 (it reads this as `amount`).
  public var shaderAmount: Double
  /// An endless zoom through the picture nested inside itself.
  public var portal: Portal?

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
      shader: container.decodeIfPresent(String.self, forKey: .shader),
      shaderAmount: container.decodeIfPresent(Double.self, forKey: .shaderAmount) ?? 1,
      portal: container.decodeIfPresent(Portal.self, forKey: .portal),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case grain
    case vignette
    case halation
    case blur
    case key
    case shader
    case shaderAmount
    case portal
  }

}
