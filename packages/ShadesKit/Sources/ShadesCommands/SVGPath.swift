import Foundation
import ShadesCore

/// Reads SVG path data (`M`, `L`, `H`, `V`, `C`, `Q`, `Z`, absolute or relative) into drawing
/// strokes, with `viewBox` (its width and height) mapped onto the whole frame.
enum SVGPath {

  // MARK: Internal

  /// The strokes the path draws (each `M` starts one); curves are followed in short steps.
  static func strokes(
    from data: String,
    viewBox: (width: Double, height: Double),
  ) throws(CommandError) -> [[DrawingPoint]] {
    let tokens = tokenize(data)
    var strokes = [[DrawingPoint]]()
    var current = [(Double, Double)]()
    var pen = (0.0, 0.0)
    var start = pen
    var command: Character = "M"
    var index = 0
    func number() throws(CommandError) -> Double {
      guard index < tokens.count, let value = Double(tokens[index]) else {
        throw rejected(.invalidValue("the SVG path ends early or has a stray letter"))
      }
      index += 1
      return value
    }
    func finish() {
      if current.count > 1 {
        strokes
          .append(current.map { DrawingPoint(x: $0.0 / viewBox.width, y: $0.1 / viewBox.height) })
      }
      current = []
    }
    while index < tokens.count {
      if let letter = tokens[index].first, letter.isLetter {
        command = letter
        index += 1
      }
      let relative = command.isLowercase
      let base = relative ? pen : (0, 0)
      switch command.uppercased() {
      case "M":
        finish()
        pen = try (base.0 + number(), base.1 + number())
        start = pen
        current = [pen]
        command = relative ? "l" : "L"

      case "L":
        pen = try (base.0 + number(), base.1 + number())
        current.append(pen)

      case "H":
        pen = try (relative ? pen.0 + number() : number(), pen.1)
        current.append(pen)

      case "V":
        pen = try (pen.0, relative ? pen.1 + number() : number())
        current.append(pen)

      case "Q":
        let control = try (base.0 + number(), base.1 + number())
        let end = try (base.0 + number(), base.1 + number())
        current += curve([pen, control, end])
        pen = end

      case "C":
        let first = try (base.0 + number(), base.1 + number())
        let second = try (base.0 + number(), base.1 + number())
        let end = try (base.0 + number(), base.1 + number())
        current += curve([pen, first, second, end])
        pen = end

      case "Z":
        current.append(start)
        pen = start
        finish()
        if index < tokens.count, tokens[index].first?.isLetter == false {
          throw rejected(.invalidValue("numbers after Z in the SVG path"))
        }

      default:
        throw rejected(
          .invalidValue("the SVG path command \(command) isn't supported (use M L H V C Q Z)")
        )
      }
    }
    finish()
    guard !strokes.isEmpty else {
      throw rejected(.invalidValue("the SVG path draws nothing"))
    }
    return strokes
  }

  // MARK: Private

  /// Letters and numbers, split on spaces, commas and where a new number starts.
  private static func tokenize(_ data: String) -> [String] {
    var tokens = [String]()
    var number = ""
    for character in data {
      if character.isLetter, character != "e" {
        if !number.isEmpty {
          tokens.append(number)
          number = ""
        }
        tokens.append(String(character))
      } else if character == "-", !number.isEmpty, number.last != "e" {
        tokens.append(number)
        number = "-"
      } else if character == "." && number.contains(".") {
        tokens.append(number)
        number = "."
      } else if character.isNumber || character == "." || character == "-" || character == "e" {
        number.append(character)
      } else if !number.isEmpty {
        tokens.append(number)
        number = ""
      }
    }
    if !number.isEmpty {
      tokens.append(number)
    }
    return tokens
  }

  /// Points along a Bézier curve (quadratic or cubic, given its control points), without its start.
  private static func curve(_ control: [(Double, Double)]) -> [(Double, Double)] {
    (1 ... 16).map { step in
      var points = control
      let t = Double(step) / 16
      while points.count > 1 {
        points = zip(points, points.dropFirst()).map { from, to in
          (from.0 + (to.0 - from.0) * t, from.1 + (to.1 - from.1) * t)
        }
      }
      return points[0]
    }
  }

}
