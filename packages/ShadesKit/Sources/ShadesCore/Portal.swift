// MARK: - Portal

/// An endless zoom: the picture holds a smaller copy of itself in its middle, which holds
/// another, forever (the Droste effect), and the view travels in through them.
public struct Portal: Hashable, Sendable {

  // MARK: Lifecycle

  public init(nesting: Double = 3, travel: Double = 0) {
    self.nesting = nesting
    self.travel = travel
  }

  // MARK: Public

  /// How many times smaller each copy is than the one around it.
  public var nesting: Double
  /// How far the view has zoomed in, in copies: 1 brings the next one in to fill the picture.
  /// Keyframes (`portal`) make it zoom on forever.
  public var travel: Double

}

// MARK: Codable

extension Portal: Codable {

  // MARK: Lifecycle

  /// Reads a portal where either field may be left out (it keeps its default).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = Portal()
    try self.init(
      nesting: container.decodeIfPresent(Double.self, forKey: .nesting) ?? base.nesting,
      travel: container.decodeIfPresent(Double.self, forKey: .travel) ?? base.travel,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case nesting
    case travel
  }

}
