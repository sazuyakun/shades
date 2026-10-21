import ShadesCommands
import ShadesCore
import SwiftUI

// MARK: - ShortLane

/// The marked shorts as named capsules above the ruler: click one to pick it, drag its ends to
/// move them, right-click to rename or remove it. Only the visible stretch is laid out.
struct ShortLane: View {

  static let height = 22.0

  let shorts: [Short]
  let scale: TimelineScale
  /// How far into the timeline the visible stretch starts, in points.
  let visibleStart: Double
  @Binding var selection: Short.ID?

  let onRun: (EditorAction) -> Void
  let onError: (String) -> Void

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(shorts) { short in
        ShortCapsule(
          short: short,
          scale: scale,
          isSelected: selection == short.id,
          onSelect: { selection = short.id },
          onRun: { action in
            selection = short.id
            onRun(action)
          },
          onError: onError,
        )
        .offset(x: scale.x(at: short.range.start) - visibleStart, y: 3)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .clipped()
  }

}

// MARK: - ShortCapsule

/// One short: its name in a capsule as long as its stretch, with ends that drag.
private struct ShortCapsule: View {

  // MARK: Internal

  let short: Short
  let scale: TimelineScale
  let isSelected: Bool
  let onSelect: () -> Void
  let onRun: (EditorAction) -> Void
  let onError: (String) -> Void

  var body: some View {
    Text(short.name)
      .font(.caption)
      .lineLimit(1)
      .padding(.horizontal, 8)
      .frame(
        width: max(scale.x(at: short.range.duration) + endShift - startShift, 16),
        height: 16,
        alignment: .leading,
      )
      .background(Color.accentColor.opacity(isSelected ? 0.4 : 0.18), in: .capsule)
      .overlay(Capsule().strokeBorder(Color.accentColor.opacity(isSelected ? 0.9 : 0.4)))
      .overlay(alignment: .leading) {
        ShortEdge(isStart: true, shift: $startShift, onEnd: resize)
      }
      .overlay(alignment: .trailing) {
        ShortEdge(isStart: false, shift: $endShift, onEnd: resize)
      }
      .offset(x: startShift)
      .onTapGesture(perform: onSelect)
      .contextMenu {
        Button("Rename…") { onRun(.renameShort) }
        Button("Move Start to Playhead") { onRun(.shortStartToPlayhead) }
        Button("Move End to Playhead") { onRun(.shortEndToPlayhead) }
        Divider()
        Button("Remove Short") { onRun(.removeShort) }
      }
      .help("\(short.name): exported on its own on the 9:16 canvas")
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  /// How far the start edge has been dragged, in points.
  @State private var startShift = 0.0
  /// How far the end edge has been dragged, in points.
  @State private var endShift = 0.0

  /// Moves the short's ends to where they were dragged.
  private func resize() {
    let start = short.range.start.seconds + scale.seconds(atX: startShift)
    let end = short.range.end.seconds + scale.seconds(atX: endShift)
    startShift = 0
    endShift = 0
    do {
      try editor.perform(SetShort(
        shortID: short.id,
        start: MediaTime(seconds: max(start, 0)),
        end: MediaTime(seconds: end),
      ))
    } catch {
      onError(error.errorDescription ?? "The short couldn't be changed.")
    }
  }

}

// MARK: - ShortEdge

/// A short's start or end, dragged sideways to move it.
private struct ShortEdge: View {
  let isStart: Bool
  @Binding var shift: Double

  let onEnd: () -> Void

  var body: some View {
    Color.clear
      .frame(width: 8)
      .contentShape(.rect)
      .pointerStyle(.frameResize(position: isStart ? .leading : .trailing))
      .highPriorityGesture(
        // why: the capsule moves with its start edge, so the drag is measured in the window.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { shift = $0.translation.width }
          .onEnded { _ in onEnd() }
      )
  }
}
