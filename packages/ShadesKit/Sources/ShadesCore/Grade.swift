// MARK: - Grade

/// A clip's colour grade: primaries, curves and an optional LUT, optionally limited to some
/// colours (a qualifier) or a shape (a window). Every field starts neutral, so a grade only
/// changes what it sets.
public struct Grade: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    exposure: Double = 0,
    contrast: Double = 1,
    saturation: Double = 1,
    temperature: Double = 0,
    tint: Double = 0,
    lift: Double = 0,
    gamma: Double = 1,
    gain: Double = 1,
    curves: Curves? = nil,
    lut: String? = nil,
    lutAmount: Double = 1,
    qualifier: Qualifier? = nil,
    window: GradeWindow? = nil,
  ) {
    self.exposure = exposure
    self.contrast = contrast
    self.saturation = saturation
    self.temperature = temperature
    self.tint = tint
    self.lift = lift
    self.gamma = gamma
    self.gain = gain
    self.curves = curves
    self.lut = lut
    self.lutAmount = lutAmount
    self.qualifier = qualifier
    self.window = window
  }

  // MARK: Public

  /// Brightness in stops: +1 is twice as bright.
  public var exposure: Double
  /// 1 is unchanged; above pushes darks and lights apart around the middle.
  public var contrast: Double
  /// 0 is black and white, 1 unchanged, 2 twice as colourful.
  public var saturation: Double
  /// −1 cool (blue) to 1 warm (orange).
  public var temperature: Double
  /// −1 green to 1 magenta.
  public var tint: Double
  /// Raises (positive) or crushes the shadows.
  public var lift: Double
  /// Above 1 brightens the midtones, below darkens them.
  public var gamma: Double
  /// Scales the highlights.
  public var gain: Double
  public var curves: Curves?
  /// A `.cube` LUT: a file path or a plugin's LUT by `plugin/name` or `name`.
  public var lut: String?
  /// How much of the LUT shows, 0 to 1.
  public var lutAmount: Double
  /// Limits the grade to some colours (a secondary correction).
  public var qualifier: Qualifier?
  /// Limits the grade to a soft shape.
  public var window: GradeWindow?

}

// MARK: Codable

extension Grade: Codable {

  // MARK: Lifecycle

  /// Reads a grade where any field may be left out (it stays neutral).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      exposure: container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0,
      contrast: container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1,
      saturation: container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1,
      temperature: container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0,
      tint: container.decodeIfPresent(Double.self, forKey: .tint) ?? 0,
      lift: container.decodeIfPresent(Double.self, forKey: .lift) ?? 0,
      gamma: container.decodeIfPresent(Double.self, forKey: .gamma) ?? 1,
      gain: container.decodeIfPresent(Double.self, forKey: .gain) ?? 1,
      curves: container.decodeIfPresent(Curves.self, forKey: .curves),
      lut: container.decodeIfPresent(String.self, forKey: .lut),
      lutAmount: container.decodeIfPresent(Double.self, forKey: .lutAmount) ?? 1,
      qualifier: container.decodeIfPresent(Qualifier.self, forKey: .qualifier),
      window: container.decodeIfPresent(GradeWindow.self, forKey: .window),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case exposure
    case contrast
    case saturation
    case temperature
    case tint
    case lift
    case gamma
    case gain
    case curves
    case lut
    case lutAmount
    case qualifier
    case window
  }

}
