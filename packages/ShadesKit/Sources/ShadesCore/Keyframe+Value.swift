extension [Keyframe] {
  /// `property`'s value at `time` (in the keyframes' own time): eased between the keyframes
  /// around it, held before the first and after the last, or `fixed` when it has none.
  public func value(of property: AnimatedProperty, at time: MediaTime, fixed: Double) -> Double {
    filter { $0.property == property }
      .sorted { $0.time < $1.time }
      .eased(
        at: time.seconds,
        time: \.time.seconds,
        hold: \.value,
        blend: { from, to, fraction in from.value(towards: to, at: fraction) },
      ) ?? fixed
  }

  /// The whole placement at `time`, from `fixed` where a property has no keyframes.
  public func transform(at time: MediaTime, fixed: ClipTransform) -> ClipTransform {
    ClipTransform(
      x: value(of: .x, at: time, fixed: fixed.x),
      y: value(of: .y, at: time, fixed: fixed.y),
      scale: value(of: .scale, at: time, fixed: fixed.scale),
      rotation: value(of: .rotation, at: time, fixed: fixed.rotation),
      tiltX: value(of: .tiltX, at: time, fixed: fixed.tiltX),
      tiltY: value(of: .tiltY, at: time, fixed: fixed.tiltY),
      depth: value(of: .depth, at: time, fixed: fixed.depth),
      bend: value(of: .bend, at: time, fixed: fixed.bend),
    )
  }
}
