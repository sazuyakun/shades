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

  /// The clip's sound level at `time` on the timeline: its volume keyframes (or fixed volume)
  /// faded in and out at its ends.
  public func gain(at time: MediaTime) -> Double {
    let elapsed = (time - timelineStart).seconds
    let remaining = (timelineEnd - time).seconds
    let fadingIn = fadeIn.seconds > 0 ? min(max(elapsed / fadeIn.seconds, 0), 1) : 1
    let fadingOut = fadeOut.seconds > 0 ? min(max(remaining / fadeOut.seconds, 0), 1) : 1
    return value(of: .volume, at: time) * fadingIn * fadingOut
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
    case .volume: volume
    }
  }

}
