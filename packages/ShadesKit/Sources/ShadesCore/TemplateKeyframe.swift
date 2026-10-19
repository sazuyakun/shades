/// A keyframe in a template layer, in seconds from the layer's start.
public struct TemplateKeyframe: Codable, Hashable, Sendable {
  public init(property: AnimatedProperty, at time: Double, value: Double, easing: Easing? = nil) {
    self.property = property
    at = time
    self.value = value
    self.easing = easing
  }

  public var property: AnimatedProperty
  public var at: Double
  public var value: Double
  public var easing: Easing?
}
