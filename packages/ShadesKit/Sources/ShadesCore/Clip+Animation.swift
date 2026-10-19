import Foundation

extension Clip {

  // MARK: Public

  /// The clip's placement at `time` on the timeline, with its keyframes applied.
  public func transform(at time: MediaTime) -> ClipTransform {
    keyframes.transform(at: sourceTime(at: time), fixed: transform)
  }

  /// The clip's opacity at `time` on the timeline, with its keyframes applied.
  public func opacity(at time: MediaTime) -> Double {
    value(of: .opacity, at: time)
  }

  /// A property's value at `time` on the timeline: from its keyframes when it has any,
  /// otherwise the clip's fixed value.
  public func value(of property: AnimatedProperty, at time: MediaTime) -> Double {
    keyframes.value(of: property, at: sourceTime(at: time), fixed: fixedValue(of: property))
  }

  /// The moment of the clip's source shown at `time` on the timeline.
  public func sourceTime(at time: MediaTime) -> MediaTime {
    time - timelineStart + sourceStart
  }

  /// The timeline moment that shows `source` of the clip's source.
  public func timelineTime(atSource source: MediaTime) -> MediaTime {
    source - sourceStart + timelineStart
  }

  // MARK: Private

  private func fixedValue(of property: AnimatedProperty) -> Double {
    switch property {
    case .x: transform.x
    case .y: transform.y
    case .scale: transform.scale
    case .rotation: transform.rotation
    case .tiltX: transform.tiltX
    case .tiltY: transform.tiltY
    case .depth: transform.depth
    case .opacity: opacity
    }
  }

}
