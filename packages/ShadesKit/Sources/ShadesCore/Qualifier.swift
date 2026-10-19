// MARK: - Qualifier

/// Picks the colours a grade changes: a range of hues (with enough colour to have a hue) and of
/// brightness, with soft edges. Everything else is left as it was.
public struct Qualifier: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    hue: Double = 0,
    hueWidth: Double = 0.08,
    minSaturation: Double = 0.15,
    brightness: [Double] = [0, 1],
    softness: Double = 0.05,
  ) {
    self.hue = hue
    self.hueWidth = hueWidth
    self.minSaturation = minSaturation
    self.brightness = brightness
    self.softness = softness
  }

  // MARK: Public

  /// The hue picked, 0 to 1 around the colour wheel (0 red, 0.08 skin, 0.33 green, 0.6 sky blue).
  public var hue: Double
  /// How far either side of `hue` still counts, 0 to 0.5.
  public var hueWidth: Double
  /// Colours greyer than this have no hue to pick, 0 to 1.
  public var minSaturation: Double
  /// The brightness range picked, from and to, each 0 to 1.
  public var brightness: [Double]
  /// How gradually the edges fade, 0 to 0.5.
  public var softness: Double

}

// MARK: Codable

extension Qualifier: Codable {

  // MARK: Lifecycle

  /// Reads a qualifier where any field may be left out.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = Qualifier()
    try self.init(
      hue: container.decodeIfPresent(Double.self, forKey: .hue) ?? base.hue,
      hueWidth: container.decodeIfPresent(Double.self, forKey: .hueWidth) ?? base.hueWidth,
      minSaturation: container.decodeIfPresent(Double.self, forKey: .minSaturation)
        ?? base.minSaturation,
      brightness: container.decodeIfPresent([Double].self, forKey: .brightness) ?? base.brightness,
      softness: container.decodeIfPresent(Double.self, forKey: .softness) ?? base.softness,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case hue
    case hueWidth
    case minSaturation
    case brightness
    case softness
  }

}
