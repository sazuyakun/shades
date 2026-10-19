import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// Draws over the viewer with the Draw tool: each drag is a stroke. A stroke starts a drawing at
/// the playhead, or adds to the selected drawing when it's showing there.
struct DrawingCanvas: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    GeometryReader { geometry in
      Path { path in
        guard let first = points.first else {
          return
        }
        path.move(to: CGPoint(x: first.x * geometry.size.width, y: first.y * geometry.size.height))
        for point in points.dropFirst() {
          path.addLine(to: CGPoint(
            x: point.x * geometry.size.width,
            y: point.y * geometry.size.height,
          ))
        }
      }
      .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      .contentShape(.rect)
      .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
        points.append(DrawingPoint(
          x: min(max(drag.location.x / geometry.size.width, 0), 1),
          y: min(max(drag.location.y / geometry.size.height, 0), 1),
        ))
      }.onEnded { _ in
        finishStroke()
      })
    }
    .overlay(Rectangle().strokeBorder(
      Theme.secondaryText.opacity(0.6),
      style: StrokeStyle(lineWidth: 1, dash: [4, 4]),
    ))
    .help("Draw Tool (P): drag to draw over the picture. Press P again to stop.")
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var points = [DrawingPoint]()

  /// Adds the stroke to the selected drawing showing at the playhead, or starts a new drawing
  /// there and selects it.
  private func finishStroke() {
    let stroke = points
    points = []
    guard stroke.count > 1 else {
      return
    }
    let playhead = MediaTime(seconds: player.currentTime)
    let timeline = editor.project.timeline
    let selected = editor.selection.compactMap(timeline.clip(withID:))
      .first { $0.drawing != nil && $0.contains(playhead) }
    do {
      if let selected {
        try editor.perform(SetDrawing(clipID: selected.id, addStrokes: [stroke]))
      } else {
        try editor.perform(AddDrawing(at: playhead, strokes: [stroke]))
        let added = editor.project.timeline.allClips.first { $0.drawing?.strokes == [stroke] }
        editor.selection = Set(added.map { [$0.id] } ?? [])
      }
    } catch {
      onError(error.errorDescription ?? "The drawing couldn't be added.")
    }
  }

}
