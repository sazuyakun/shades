import ShadesPolish
import SwiftUI

/// A Polish plan drawn over its track: tinted stripes over the time each cut removes, a light
/// band over stretches that get a punch-in, and a tick where a cut snaps to a beat. Switched-off
/// items show faintly.
struct PolishOverlay: View {
  let items: [PolishItem]
  let scale: TimelineScale

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(items) { item in
        let x = scale.x(at: item.range.start)
        let width = max(scale.x(at: item.range.duration), 2)
        let color = PolishColors.color(of: item.kind)
        switch item.kind {
        case .silence,
             .filler,
             .retake:
          Rectangle()
            .fill(color.opacity(item.isEnabled ? 0.35 : 0.1))
            .overlay { Rectangle().strokeBorder(
              color.opacity(item.isEnabled ? 0.9 : 0.3),
              lineWidth: 1,
            ) }
            .frame(width: width)
            .offset(x: x)

        case .punchIn:
          Rectangle()
            .fill(color.opacity(item.isEnabled ? 0.5 : 0.15))
            .frame(width: width, height: 3)
            .offset(x: x)

        case .beatSnap:
          Rectangle()
            .fill(color.opacity(item.isEnabled ? 1 : 0.3))
            .frame(width: 2)
            .offset(x: x)
        }
      }
    }
    .allowsHitTesting(false)
  }
}
