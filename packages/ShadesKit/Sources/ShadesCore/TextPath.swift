/// A path text is laid along, letter by letter, standing on it and turning with it.
public struct TextPath: Codable, Hashable, Sendable {
  public init(points: [DrawingPoint], offset: Double = 0) {
    self.points = points
    self.offset = offset
  }

  /// The path through the frame; one that ends where it starts is a loop the text can circle.
  public var points: [DrawingPoint]
  /// How far the text is moved along the path from where its alignment puts it, as a fraction
  /// of the path's length: positive moves it towards the end. Keyframes (`pathOffset`) make the
  /// text travel.
  public var offset: Double
}
