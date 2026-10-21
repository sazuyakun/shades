extension Array {
  /// The value at `seconds` along elements sorted by `time`: `hold` of the first before it
  /// starts and of the last after it ends, otherwise `blend` of the two around it and how far
  /// between them it is (0 to 1). `nil` when there are no elements.
  func eased<Value>(
    at seconds: Double,
    time: (Element) -> Double,
    hold: (Element) -> Value,
    blend: (Element, Element, Double) -> Value,
  ) -> Value? {
    guard let first, let last else {
      return nil
    }
    guard seconds > time(first) else {
      return hold(first)
    }
    guard let next = firstIndex(where: { time($0) > seconds }) else {
      return hold(last)
    }
    let from = self[next - 1]
    let to = self[next]
    return blend(from, to, (seconds - time(from)) / (time(to) - time(from)))
  }
}
