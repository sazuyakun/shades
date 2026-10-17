import ShadesCore
import SwiftUI

/// Time labels, ticks and markers above the tracks. Only the visible stretch is drawn, so deep
/// zoom stays cheap.
struct TimelineRuler: View {

  // MARK: Internal

  static let height = 24.0

  let scale: TimelineScale
  let markers: [Marker]
  /// The scroll position: how far into the timeline the visible stretch starts, in points.
  let visibleStart: Double

  var body: some View {
    Canvas { context, size in
      let step = Self.steps.first { scale.x(atSeconds: $0) >= 70 } ?? 600
      var seconds = (scale.seconds(atX: visibleStart) / step).rounded(.down) * step
      while scale.x(atSeconds: seconds) - visibleStart < size.width {
        let x = scale.x(atSeconds: seconds) - visibleStart
        context.fill(
          Path(CGRect(x: x, y: size.height - 5, width: 1, height: 5)),
          with: .color(Theme.strongHairline),
        )
        context.draw(
          Text(Timecode.short(seconds)).font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.faintText),
          at: CGPoint(x: x + 4, y: 10),
          anchor: .leading,
        )
        seconds += step
      }
      for marker in markers {
        let x = scale.x(at: marker.time) - visibleStart
        var flag = Path()
        flag.move(to: CGPoint(x: x - 4, y: size.height - 9))
        flag.addLine(to: CGPoint(x: x + 4, y: size.height - 9))
        flag.addLine(to: CGPoint(x: x, y: size.height - 2))
        context.fill(flag, with: .color(Theme.marker))
      }
    }
    .frame(height: Self.height)
  }

  // MARK: Private

  /// Tick spacings to choose from, in seconds; the first one at least 70 points wide wins.
  private static let steps: [Double] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300]

}
