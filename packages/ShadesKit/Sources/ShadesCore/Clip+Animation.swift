import Foundation

extension Clip {

  // MARK: Public

  /// The clip's placement at `time` on the timeline, with its keyframes applied.
  public func transform(at time: MediaTime) -> ClipTransform {
    ClipTransform(
      x: value(of: .x, at: time),
      y: value(of: .y, at: time),
      scale: value(of: .scale, at: time),
      rotation: value(of: .rotation, at: time),
    )
  }

  /// The clip's opacity at `time` on the timeline, with its keyframes applied.
  public func opacity(at time: MediaTime) -> Double {
    value(of: .opacity, at: time)
  }

  /// A property's value at `time` on the timeline: from its keyframes when it has any,
  /// otherwise the clip's fixed value.
  public func value(of property: AnimatedProperty, at time: MediaTime) -> Double {
    let keys = keyframes.filter { $0.property == property }.sorted { $0.time < $1.time }
    guard let first = keys.first, let last = keys.last else {
      return fixedValue(of: property)
    }
    let source = sourceTime(at: time).seconds
    guard source > first.time.seconds else {
      return first.value
    }
    guard let next = keys.firstIndex(where: { $0.time.seconds > source }) else {
      return last.value
    }
    let from = keys[next - 1]
    let to = keys[next]
    let fraction = (source - from.time.seconds) / (to.time.seconds - from.time.seconds)
    return from.value + (to.value - from.value) * from.easing.progress(fraction)
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
    case .opacity: opacity
    }
  }

}
