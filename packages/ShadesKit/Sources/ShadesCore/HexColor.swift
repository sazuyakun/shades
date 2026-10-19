import Foundation

// MARK: - HexColor

/// A colour written as `#RRGGBB` or `#RRGGBBAA`, the way Claude and plugins give colours.
public struct HexColor: Hashable, Sendable {

  // MARK: Lifecycle

  /// Reads `#RRGGBB` or `#RRGGBBAA` (the `#` is optional); `nil` if it isn't one.
  public init?(_ hex: String) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else {
      return nil
    }
    let full = digits.count == 6 ? value << 8 | 0xFF : value
    red = Double(full >> 24 & 0xFF) / 255
    green = Double(full >> 16 & 0xFF) / 255
    blue = Double(full >> 8 & 0xFF) / 255
    alpha = Double(full & 0xFF) / 255
  }

  private init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  // MARK: Public

  public static let white = HexColor(red: 1, green: 1, blue: 1)
  public static let black = HexColor(red: 0, green: 0, blue: 0)

  public let red: Double
  public let green: Double
  public let blue: Double
  public let alpha: Double

  /// The colour as `#RRGGBB`, or `#RRGGBBAA` when it's see-through.
  public var hex: String {
    let parts = [red, green, blue] + (alpha < 1 ? [alpha] : [])
    return "#" + parts.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
  }

}

// MARK: Codable

extension HexColor: Codable {

  // MARK: Lifecycle

  public init(from decoder: any Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    guard let color = HexColor(text) else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath,
        debugDescription: "\(text) isn't a colour like #FFFFFF",
      ))
    }
    self = color
  }

  // MARK: Public

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(hex)
  }

}
