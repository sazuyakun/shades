// MARK: - Drawing

/// Hand-drawn lines over the picture: strokes that can wobble like hand animation ("boil") and
/// draw themselves on.
public struct Drawing: Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    strokes: [[DrawingPoint]],
    color: HexColor = .white,
    width: Double = 0.006,
    glow: Double = 0,
    boil: Double = 12,
    writeOn: Double = 0,
  ) {
    self.strokes = strokes
    self.color = color
    self.width = width
    self.glow = glow
    self.boil = boil
    self.writeOn = writeOn
  }

  // MARK: Public

  /// Each stroke's points, in order, as fractions of the frame from its top left.
  public var strokes: [[DrawingPoint]]
  public var color: HexColor
  /// Line thickness as a fraction of the frame's height.
  public var width: Double
  /// How much the line glows, 0 (none) to 1.
  public var glow: Double
  /// How many times a second the line is redrawn with a new wobble; 0 holds it still.
  public var boil: Double
  /// Seconds the lines take to draw themselves on, in stroke order; 0 shows them at once.
  public var writeOn: Double

}

// MARK: Codable

extension Drawing: Codable {

  // MARK: Lifecycle

  /// Reads a drawing where any style may be left out.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      strokes: container.decode([[DrawingPoint]].self, forKey: .strokes),
      color: container.decodeIfPresent(HexColor.self, forKey: .color) ?? .white,
      width: container.decodeIfPresent(Double.self, forKey: .width) ?? 0.006,
      glow: container.decodeIfPresent(Double.self, forKey: .glow) ?? 0,
      boil: container.decodeIfPresent(Double.self, forKey: .boil) ?? 12,
      writeOn: container.decodeIfPresent(Double.self, forKey: .writeOn) ?? 0,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case strokes
    case color
    case width
    case glow
    case boil
    case writeOn
  }

}
