/// How a clip comes in from the clip just before it on its track, centred on the cut.
public struct Transition: Codable, Hashable, Sendable {
  public init(kind: TransitionKind, duration: MediaTime) {
    self.kind = kind
    self.duration = duration
  }

  public var kind: TransitionKind
  /// The whole transition, half before the cut and half after.
  public var duration: MediaTime
}
