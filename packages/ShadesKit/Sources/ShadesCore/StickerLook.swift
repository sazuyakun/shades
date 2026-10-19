/// The die-cut sticker look for a cut-out picture: a white border hugging its outline and a soft
/// drop shadow.
public struct StickerLook: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(border: Double = 0.04, shadow: Bool = true) {
    self.border = border
    self.shadow = shadow
  }

  /// Reads a look where either field may be left out.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      border: container.decodeIfPresent(Double.self, forKey: .border) ?? 0.04,
      shadow: container.decodeIfPresent(Bool.self, forKey: .shadow) ?? true,
    )
  }

  // MARK: Public

  /// Border width as a fraction of the picture's shorter side; 0 is none.
  public var border: Double
  public var shadow: Bool

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case border
    case shadow
  }

}
