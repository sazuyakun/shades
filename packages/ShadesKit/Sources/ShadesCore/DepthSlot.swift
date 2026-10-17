/// Where a layer is drawn relative to the subject (the person or object cut out by its matte).
/// The frame is drawn background → behind subject → subject → inside subject → in front.
public enum DepthSlot: String, Codable, Sendable, CaseIterable {
  /// Over everything, like captions.
  case inFront
  /// Between the background and the subject, like big text behind a person.
  case behindSubject
  /// Only inside the subject's outline.
  case insideSubject
  /// Instead of the background.
  case replaceBackground
}
