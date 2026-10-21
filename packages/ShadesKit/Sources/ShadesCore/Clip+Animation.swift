import Foundation

extension Clip {

  // MARK: Public

  /// The speeds whose sound still plays, stretched with its pitch kept.
  public static let audibleSpeeds: ClosedRange<Double> = 0.25 ... 4

  /// Whether it holds one frame: speed 0 with no speed keyframes.
  public var isFrozen: Bool {
    speed == 0 && !hasSpeedRamp
  }

  /// Whether its speed changes over time, along speed keyframes.
  public var hasSpeedRamp: Bool {
    keyframes.contains { $0.property == .speed }
  }

  /// Whether it plays its media at anything but normal speed.
  public var isRetimed: Bool {
    speed != 1 || hasSpeedRamp
  }

  /// The moment of its source the clip reaches at its end: where it stops in its media.
  public var sourceEnd: MediaTime {
    sourceTime(at: timelineEnd)
  }

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
    let level = playsSound(at: time) ? value(of: .volume, at: time) : 0
    return level * fadingIn * fadingOut
  }

  /// Whether its sound plays at `time`: not on a freeze frame, nor at a speed too far from
  /// normal to stretch the sound well.
  public func playsSound(at time: MediaTime) -> Bool {
    Self.audibleSpeeds.contains(value(of: .speed, at: time))
  }

  /// The moment of the clip's source shown at `time` on the timeline: the clip's speed (or its
  /// speed keyframes, summed along the way) decides how far through its source it has got.
  public func sourceTime(at time: MediaTime) -> MediaTime {
    if isFrozen {
      return sourceStart
    }
    if !isRetimed {
      return time - timelineStart + sourceStart
    }
    let elapsed = (time - timelineStart).seconds
    return MediaTime(seconds: speedCurve.sourceSeconds(from: sourceStart.seconds, after: elapsed))
  }

  /// The timeline moment that shows `source` of the clip's source (the start, on a freeze frame).
  public func timelineTime(atSource source: MediaTime) -> MediaTime {
    if isFrozen {
      return timelineStart
    }
    if !isRetimed {
      return source - sourceStart + timelineStart
    }
    let seconds = speedCurve.timelineSeconds(from: sourceStart.seconds, to: source.seconds)
    return timelineStart + MediaTime(seconds: seconds)
  }

  // MARK: Private

  private var speedCurve: SpeedCurve {
    SpeedCurve(speed: speed, keyframes: keyframes)
  }

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
    case .speed: speed
    }
  }

}
