/// How a text clip's words come on screen over time (kinetic type).
public enum TextReveal: String, Codable, CaseIterable, Sendable {
  /// All at once.
  case none
  /// Each word pops in as it's said, and stays.
  case pop
  /// All words shown, the one being said in the highlight colour.
  case highlight
  /// Letter by letter, as if typed.
  case typewriter
}
