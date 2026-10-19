/// A title or motion template from a plugin: layers placed together at a moment, with text
/// fields (written `{name}`) filled in when it's used.
public struct Template: Codable, Hashable, Sendable {

  // MARK: Lifecycle

  public init(duration: Double = 3, layers: [TemplateLayer]) {
    self.duration = duration
    self.layers = layers
  }

  /// Reads a template whose duration may be left out (3 seconds).
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    try self.init(
      duration: container.decodeIfPresent(Double.self, forKey: .duration) ?? 3,
      layers: container.decode([TemplateLayer].self, forKey: .layers),
    )
  }

  // MARK: Public

  /// How long its layers stay, in seconds, unless a layer says otherwise.
  public var duration: Double
  public var layers: [TemplateLayer]

  /// The `{name}` fields its text asks for, in order of first use.
  public var fields: [String] {
    var names = [String]()
    for text in layers.compactMap(\.text) {
      var rest = Substring(text)
      while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
        let name = String(rest[rest.index(after: open) ..< close])
        if !name.isEmpty, !names.contains(name) {
          names.append(name)
        }
        rest = rest[rest.index(after: close)...]
      }
    }
    return names
  }

  // MARK: Internal

  enum CodingKeys: String, CodingKey {
    case duration
    case layers
  }

}
