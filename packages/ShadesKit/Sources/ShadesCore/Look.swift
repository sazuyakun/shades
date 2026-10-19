/// A ready-made look from a plugin: a grade, effects and a blend mode, any of which may be
/// left out.
public struct Look: Codable, Hashable, Sendable {
  public init(grade: Grade? = nil, effects: Effects? = nil, blend: BlendMode? = nil) {
    self.grade = grade
    self.effects = effects
    self.blend = blend
  }

  public var grade: Grade?
  public var effects: Effects?
  public var blend: BlendMode?
}
