// MARK: - Crop

/// How much is cut off each edge of a clip's picture, as fractions of its upright width (left
/// and right) or height (top and bottom). The picture keeps its size and place; the cut edges
/// turn see-through.
public struct Crop: Hashable, Sendable {

  // MARK: Lifecycle

  public init(left: Double = 0, right: Double = 0, top: Double = 0, bottom: Double = 0) {
    self.left = left
    self.right = right
    self.top = top
    self.bottom = bottom
  }

  // MARK: Public

  public static let none = Crop()

  public var left: Double
  public var right: Double
  public var top: Double
  public var bottom: Double

}

// MARK: Codable

extension Crop: Codable {

  // MARK: Lifecycle

  /// Reads a crop where any edge may be left out (nothing cut off it).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      left: container.decodeIfPresent(Double.self, forKey: .left) ?? 0,
      right: container.decodeIfPresent(Double.self, forKey: .right) ?? 0,
      top: container.decodeIfPresent(Double.self, forKey: .top) ?? 0,
      bottom: container.decodeIfPresent(Double.self, forKey: .bottom) ?? 0,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case left
    case right
    case top
    case bottom
  }

}
