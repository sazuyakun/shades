import AppKit
import ShadesCore
import SwiftUI

extension HexColor {

  // MARK: Lifecycle

  /// A colour picked in SwiftUI, or `nil` when it has no sRGB form.
  init?(_ color: Color) {
    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else {
      return nil
    }
    self.init(
      red: rgb.redComponent,
      green: rgb.greenComponent,
      blue: rgb.blueComponent,
      alpha: rgb.alphaComponent,
    )
  }

  // MARK: Internal

  /// The colour for SwiftUI.
  var color: Color {
    Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

}
