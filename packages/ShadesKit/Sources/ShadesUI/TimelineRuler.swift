import SwiftUI

/// Time labels and ticks above the tracks.
struct TimelineRuler: View {

  // MARK: Internal

  let scale: TimelineScale

  var body: some View {
    Canvas { context, size in
      let step = Self.steps.first { scale.x(atSeconds: $0) >= 70 } ?? 600
      var seconds = 0.0
      while scale.x(atSeconds: seconds) < size.width {
        let x = scale.x(atSeconds: seconds)
        context.fill(
          Path(CGRect(x: x, y: size.height - 6, width: 1, height: 6)),
          with: .color(.gray),
        )
        context.draw(
          Text(Timecode.short(seconds)).font(.caption2.monospacedDigit()).foregroundStyle(.gray),
          at: CGPoint(x: x + 4, y: 9),
          anchor: .leading,
        )
        seconds += step
      }
    }
    .frame(height: 24)
  }

  // MARK: Private

  /// Tick spacings to choose from, in seconds; the first one at least 70 points wide wins.
  private static let steps: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300]

}
