import ShadesCommands
import ShadesCore
import SwiftUI

// MARK: - TimelineRuler

/// Time labels, ticks and named markers above the tracks; right-click a marker to remove it.
/// Only the visible stretch is drawn, so deep zoom stays cheap.
struct TimelineRuler: View {

  // MARK: Internal

  static let height = 24.0

  let scale: TimelineScale
  let markers: [Marker]
  /// The scroll position: how far into the timeline the visible stretch starts, in points.
  let visibleStart: Double
  let onError: (String) -> Void

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
    }
    .overlay(alignment: .bottomLeading) {
      ForEach(markers) { marker in
        MarkerFlag(name: marker.name)
          .offset(x: scale.x(at: marker.time) - visibleStart - MarkerFlag.halfWidth)
          .contextMenu {
            Button("Remove Marker") { remove(marker) }
          }
      }
    }
    .clipped()
    .frame(height: Self.height)
  }

  // MARK: Private

  /// Tick spacings to choose from, in seconds; the first one at least 70 points wide wins.
  private static let steps: [Double] = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300]

  @Environment(Editor.self) private var editor

  private func remove(_ marker: Marker) {
    do {
      try editor.perform(RemoveMarker(markerID: marker.id))
    } catch {
      onError(error.errorDescription ?? "The marker couldn't be removed.")
    }
  }

}

// MARK: - MarkerFlag

/// A marker's flag, with its name beside it.
private struct MarkerFlag: View {

  static let halfWidth = 4.0

  let name: String

  var body: some View {
    HStack(alignment: .bottom, spacing: 3) {
      Path { flag in
        flag.move(to: CGPoint(x: 0, y: 0))
        flag.addLine(to: CGPoint(x: Self.halfWidth * 2, y: 0))
        flag.addLine(to: CGPoint(x: Self.halfWidth, y: 7))
      }
      .fill(Theme.marker)
      .frame(width: Self.halfWidth * 2, height: 7)
      .padding(.bottom, 2)
      if !name.isEmpty {
        Text(name)
          .font(.system(size: 10))
          .foregroundStyle(Theme.marker)
          .lineLimit(1)
          .padding(.bottom, 1)
      }
    }
    .contentShape(.rect)
    .help(name.isEmpty ? "Marker" : name)
  }

}
