extension [Keyframe] {
  /// `property`'s value at `time` (in the keyframes' own time): eased between the keyframes
  /// around it, held before the first and after the last, or `fixed` when it has none.
  public func value(of property: AnimatedProperty, at time: MediaTime, fixed: Double) -> Double {
    let keys = filter { $0.property == property }.sorted { $0.time < $1.time }
    guard let first = keys.first, let last = keys.last else {
      return fixed
    }
    let seconds = time.seconds
    guard seconds > first.time.seconds else {
      return first.value
    }
    guard let next = keys.firstIndex(where: { $0.time.seconds > seconds }) else {
      return last.value
    }
    let from = keys[next - 1]
    let to = keys[next]
    let fraction = (seconds - from.time.seconds) / (to.time.seconds - from.time.seconds)
    return from.value + (to.value - from.value) * from.easing.progress(fraction)
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
    )
  }
}
