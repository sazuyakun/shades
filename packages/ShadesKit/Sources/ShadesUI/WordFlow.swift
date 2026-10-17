import SwiftUI

/// Lays out views like words in a paragraph: left to right, wrapping onto new lines.
struct WordFlow: Layout {

  // MARK: Internal

  var spacing = 4.0
  var lineSpacing = 4.0

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    let frames = arrange(subviews, width: width)
    let height = frames.map(\.maxY).max() ?? 0
    return CGSize(width: proposal.width ?? frames.map(\.maxX).max() ?? 0, height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout (),
  ) {
    for (subview, frame) in zip(subviews, arrange(subviews, width: bounds.width)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: .unspecified,
      )
    }
  }

  // MARK: Private

  /// Each subview's frame, wrapping when the next one wouldn't fit in `width`.
  private func arrange(_ subviews: Subviews, width: Double) -> [CGRect] {
    var frames = [CGRect]()
    var x = 0.0
    var y = 0.0
    var lineHeight = 0.0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += lineHeight + lineSpacing
        lineHeight = 0
      }
      frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
      x += size.width + spacing
      lineHeight = max(lineHeight, size.height)
    }
    return frames
  }

}
