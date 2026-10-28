/// How a picture of another shape sits in the frame: inside it with black around (`fit`), or
/// covering it with its edges cropped off (`fill`).
public enum ClipFit: String, Codable, Hashable, Sendable {
  case fit
  case fill
}
