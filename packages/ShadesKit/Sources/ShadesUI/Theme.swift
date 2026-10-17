import SwiftUI

/// The v2 palette from docs/DESIGN.md: one warm near-black, hairline dividers, warm greys.
/// Selection uses the system accent color; purple is reserved for Claude's changes.
enum Theme {
  static let background = rgb(0x14, 0x12, 0x10)
  static let raised = rgb(0x1B, 0x19, 0x16)
  static let pressed = rgb(0x2C, 0x29, 0x25)
  static let hairline = rgb(0x2A, 0x27, 0x23)
  static let strongHairline = rgb(0x34, 0x30, 0x2B)
  static let viewer = rgb(0x0F, 0x0E, 0x0C)
  static let text = rgb(0xEC, 0xE8, 0xE3)
  static let secondaryText = rgb(0x8F, 0x8A, 0x84)
  static let faintText = rgb(0x5F, 0x5A, 0x54)
  static let videoClip = rgb(0x2C, 0x44, 0x66)
  static let claude = rgb(0xB5, 0x8C, 0xFF)
  static let positive = rgb(0x5F, 0xC2, 0x7A)
  static let negative = rgb(0xE0, 0x6A, 0x6A)

  private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
    Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
  }
}
