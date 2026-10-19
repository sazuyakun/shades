// MARK: - TextStyle

/// How text looks: font, size, colour, outline, shadow, and where it sits.
public struct TextStyle: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(
    font: String? = nil,
    size: Double = 0.075,
    color: HexColor = .white,
    outlineColor: HexColor = .black,
    outline: Double = 0.04,
    shadow: Bool = true,
    align: TextAlign = .center,
    anchor: TextAnchor = .bottom,
    highlight: HexColor? = nil,
  ) {
    self.font = font
    self.size = size
    self.color = color
    self.outlineColor = outlineColor
    self.outline = outline
    self.shadow = shadow
    self.align = align
    self.anchor = anchor
    self.highlight = highlight
  }

  // MARK: Public

  /// The look captions get: bold white with a dark outline near the bottom.
  public static let caption = TextStyle()

  /// A font's name (from the Mac or a plugin); `nil` is the system's bold.
  public var font: String?
  /// Letter height as a fraction of the frame's height.
  public var size: Double
  public var color: HexColor
  public var outlineColor: HexColor
  /// Outline thickness as a fraction of the size; 0 is none.
  public var outline: Double
  public var shadow: Bool
  public var align: TextAlign
  /// Where the text sits before the clip's own position moves it.
  public var anchor: TextAnchor
  /// The colour of the word being said, for the highlight reveal (default yellow).
  public var highlight: HexColor?

}

// MARK: Codable

extension TextStyle {

  // MARK: Lifecycle

  /// Reads a style where any field may be left out (it keeps the caption look's value), so
  /// plugins and Claude only give what they change.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let base = TextStyle.caption
    try self.init(
      font: container.decodeIfPresent(String.self, forKey: .font),
      size: container.decodeIfPresent(Double.self, forKey: .size) ?? base.size,
      color: container.decodeIfPresent(HexColor.self, forKey: .color) ?? base.color,
      outlineColor: container.decodeIfPresent(HexColor.self, forKey: .outlineColor)
        ?? base.outlineColor,
      outline: container.decodeIfPresent(Double.self, forKey: .outline) ?? base.outline,
      shadow: container.decodeIfPresent(Bool.self, forKey: .shadow) ?? base.shadow,
      align: container.decodeIfPresent(TextAlign.self, forKey: .align) ?? base.align,
      anchor: container.decodeIfPresent(TextAnchor.self, forKey: .anchor) ?? base.anchor,
      highlight: container.decodeIfPresent(HexColor.self, forKey: .highlight),
    )
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case font
    case size
    case color
    case outlineColor
    case outline
    case shadow
    case align
    case anchor
    case highlight
  }

}
