import Foundation

/// Formats sound levels the way mixers read them.
enum Level {
  /// Linear gain as decibels: 1 → "+0.0 dB", 2 → "+6.0 dB", 0 → "−∞ dB".
  static func decibels(_ gain: Double) -> String {
    guard gain > 0.001 else {
      return "−∞ dB"
    }
    return String(format: "%+.1f dB", 20 * log10(gain))
  }

  /// A pan position: "L 50", "C" or "R 100".
  static func pan(_ pan: Double) -> String {
    let amount = Int((abs(pan) * 100).rounded())
    guard amount > 0 else {
      return "C"
    }
    return "\(pan < 0 ? "L" : "R") \(amount)"
  }
}
