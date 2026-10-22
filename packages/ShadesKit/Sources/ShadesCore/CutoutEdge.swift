// MARK: - CutoutEdge

/// How a clip's cut-out edge is refined before it hides or shows layers: softened, pulled in or
/// pushed out, and smoothed. Distances are fractions of the picture's width.
public struct CutoutEdge: Hashable, Sendable {

  // MARK: Lifecycle

  public init(feather: Double = 0, choke: Double = 0, smoothing: Double = 0) {
    self.feather = feather
    self.choke = choke
    self.smoothing = smoothing
  }

  // MARK: Public

  /// The edge as the cut-out made it.
  public static let none = CutoutEdge()

  /// How wide the edge's fade is.
  public var feather: Double
  /// How far the edge is pulled in (positive) or pushed out (negative).
  public var choke: Double
  /// How much jagged edges and small holes are rounded off, 0 to 1.
  public var smoothing: Double

}

// MARK: Codable

extension CutoutEdge: Codable {

  // MARK: Lifecycle

  /// Reads an edge where any field may be left out (left as the cut-out made it).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      feather: container.decodeIfPresent(Double.self, forKey: .feather) ?? 0,
      choke: container.decodeIfPresent(Double.self, forKey: .choke) ?? 0,
      smoothing: container.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0,
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case feather
    case choke
    case smoothing
  }

}
