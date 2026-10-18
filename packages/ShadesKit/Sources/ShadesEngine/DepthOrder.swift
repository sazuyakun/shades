import ShadesCore

// MARK: - DepthOrder

/// The order a frame's layers are drawn in, given their depth slots. The base is the lowest
/// video layer that has a cut-out: the frame is background → behind-subject layers → the base's
/// subject (cut out) → inside-subject layers (masked by the subject) → in-front layers. Without
/// a cut-out, or with no layer that needs one, layers draw in track order.
enum DepthOrder {

  /// How to draw layers given, bottom to top, their slots and which have a cut-out.
  static func steps(depths: [DepthSlot], hasMatte: [Bool]) -> (steps: [DrawStep], maskBase: Int?) {
    let inTrackOrder = (depths.indices.map(DrawStep.plain), nil as Int?)
    guard
      let base = hasMatte.firstIndex(of: true),
      depths.indices.contains(where: { $0 > base && depths[$0] != .inFront })
    else {
      return inTrackOrder
    }
    let above = depths.indices.filter { $0 > base }
    let replacements = above.filter { depths[$0] == .replaceBackground }
    var steps = (0 ..< base).map(DrawStep.plain)
    steps += replacements.isEmpty ? [.plain(base)] : replacements.map(DrawStep.plain)
    steps += above.filter { depths[$0] == .behindSubject }.map(DrawStep.plain)
    steps.append(.cutOut(base))
    steps += above.filter { depths[$0] == .insideSubject }.map(DrawStep.masked)
    steps += above.filter { depths[$0] == .inFront }.map(DrawStep.plain)
    return (steps, base)
  }

}

// MARK: - DrawStep

/// One layer drawn, and how.
enum DrawStep: Equatable {
  /// Drawn whole.
  case plain(Int)
  /// The subject: the layer drawn only where its cut-out is.
  case cutOut(Int)
  /// Drawn only inside the subject's outline.
  case masked(Int)
}
