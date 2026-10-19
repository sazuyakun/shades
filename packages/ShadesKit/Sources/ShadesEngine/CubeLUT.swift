import Foundation

/// A `.cube` colour lookup table: for every colour on a grid, the colour it becomes.
struct CubeLUT {

  // MARK: Lifecycle

  /// Reads a `.cube` file; `nil` when it isn't one.
  init?(contentsOf url: URL) {
    // why: an unreadable file is the same as a missing LUT to the caller, which logs it.
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
      return nil
    }
    var size = 0
    var values = [Float]()
    for line in text.split(whereSeparator: \.isNewline) {
      let parts = line.split(whereSeparator: \.isWhitespace)
      guard let first = parts.first, !first.hasPrefix("#") else {
        continue
      }
      if first == "LUT_3D_SIZE", parts.count > 1 {
        size = Int(parts[1]) ?? 0
      } else if
        parts.count == 3, let red = Float(parts[0]), let green = Float(parts[1]),
        let blue = Float(parts[2])
      {
        values += [red, green, blue, 1]
      }
    }
    guard size > 1, values.count == size * size * size * 4 else {
      return nil
    }
    self.size = size
    self.values = values
  }

  // MARK: Internal

  /// Points along each side of the grid.
  let size: Int
  /// RGBA per grid point, red changing fastest, as `.cube` files list them.
  let values: [Float]

}
