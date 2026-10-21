import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

// MARK: - MaskOverlay

/// The selected clip's masks over the viewer: drag a mask's centre to move it, its corner to
/// size it, or a path's point to reshape it; with Draw Mask, drag around something to mask it
/// with a free outline. Once a mask has keyframes, changes keyframe it at the playhead.
struct MaskOverlay: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    GeometryReader { geometry in
      if let target {
        let place = MaskPlacement(
          project: editor.project,
          clip: target.clip,
          aspect: target.aspect,
          playhead: playhead,
          size: geometry.size,
        )
        ZStack(alignment: .topLeading) {
          ForEach(target.clip.masks.indices, id: \.self) { index in
            MaskHandles(
              place: place,
              index: index,
              mask: target.clip.masks[index].placed(at: target.clip.sourceTime(at: playhead)),
              isKeyframed: !target.clip.masks[index].keyframes.isEmpty,
              onError: onError,
            )
          }
          if isDrawing {
            MaskLasso(place: place, onFinish: { isDrawing = false }, onError: onError)
          }
        }
        .coordinateSpace(.named(MaskPlacement.space))
        .overlay(alignment: .bottomTrailing) {
          Button("Draw Mask", systemImage: "lasso") { isDrawing.toggle() }
            .buttonStyle(CapsuleButtonStyle(isOn: isDrawing))
            .padding(8)
            .help("Drag around something in the picture to mask the selected clip to it")
        }
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var isDrawing = false

  private var playhead: MediaTime {
    MediaTime(seconds: player.currentTime)
  }

  /// The one selected clip showing at the playhead, if its picture's shape is known.
  private var target: (clip: Clip, aspect: Double)? {
    let timeline = editor.project.timeline
    guard
      editor.selection.count == 1, let id = editor.selection.first,
      let clip = timeline.clip(withID: id), clip.contains(playhead),
      timeline.tracks.first(where: { $0.clips.contains { $0.id == id } })?.kind != .audio,
      let aspect = editor.project.pictureAspect(of: clip)
    else {
      return nil
    }
    return (clip, aspect)
  }

}

// MARK: - MaskLasso

/// Drag around something to mask the clip to it: the outline becomes a path mask.
private struct MaskLasso: View {

  // MARK: Internal

  let place: MaskPlacement
  let onFinish: () -> Void
  let onError: (String) -> Void

  var body: some View {
    Path { path in
      path.addLines(outline)
    }
    .stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
    .contentShape(.rect)
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .named(MaskPlacement.space))
        .onChanged { outline.append($0.location) }
        .onEnded { _ in finish() }
    )
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @State private var outline = [CGPoint]()

  /// Turns the dragged outline into a path mask around it.
  private func finish() {
    let points = outline.map(place.picturePoint)
    outline = []
    onFinish()
    guard
      points.count >= 3,
      let left = points.map(\.x).min(), let right = points.map(\.x).max(),
      let top = points.map(\.y).min(), let bottom = points.map(\.y).max(),
      right > left, bottom > top
    else {
      return
    }
    let step = max(1, points.count / 128)
    let kept = stride(from: 0, to: points.count, by: step).map { points[$0] }
    do {
      try editor.perform(SetMask(
        clipID: place.clip.id,
        x: (left + right) / 2,
        y: (top + bottom) / 2,
        width: right - left,
        height: bottom - top,
        points: kept.map {
          DrawingPoint(x: ($0.x - left) / (right - left), y: ($0.y - top) / (bottom - top))
        },
      ))
    } catch {
      onError(error.errorDescription ?? "The mask couldn't be added.")
    }
  }

}

// MARK: - MaskPlacement

/// Where a clip's picture sits in the viewer at the playhead: turns its picture points into
/// viewer points and back (the camera and 3D tilt aside).
struct MaskPlacement {

  /// The coordinate space mask gestures are measured in.
  static let space = "masks"

  let project: Project
  let clip: Clip
  let aspect: Double
  let playhead: MediaTime
  let size: CGSize

  /// The viewer point showing `point` of the picture (fractions from its top left).
  func viewPoint(_ point: CGPoint) -> CGPoint {
    let offset = project.frameOffset(
      of: (point.x, point.y),
      in: clip,
      pictureAspect: aspect,
      at: playhead,
    )
    return CGPoint(x: (offset.x + 0.5) * size.width, y: (offset.y + 0.5) * size.height)
  }

  /// The picture point (fractions from its top left) showing at viewer point `point`.
  func picturePoint(_ point: CGPoint) -> CGPoint {
    let picture = project.picturePoint(
      at: (point.x / size.width - 0.5, point.y / size.height - 0.5),
      in: clip,
      pictureAspect: aspect,
      at: playhead,
    )
    return CGPoint(x: picture.x, y: picture.y)
  }

}

// MARK: - MaskHandles

/// One mask's outline and the handles that move, size and reshape it.
private struct MaskHandles: View {

  // MARK: Internal

  let place: MaskPlacement
  let index: Int
  /// The mask as it is at the playhead.
  let mask: LayerMask
  let isKeyframed: Bool
  let onError: (String) -> Void

  var body: some View {
    Path { path in
      path.addLines(outline.map(place.viewPoint))
      path.closeSubpath()
    }
    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    .allowsHitTesting(false)
    MaskHandle(place: place, at: CGPoint(x: mask.x, y: mask.y), isCentre: true) { picture in
      perform(SetMask(
        clipID: place.clip.id,
        index: index,
        x: picture.x,
        y: picture.y,
        at: isKeyframed ? place.playhead : nil,
      ))
    }
    MaskHandle(
      place: place,
      at: CGPoint(x: mask.x + mask.width / 2, y: mask.y + mask.height / 2),
    ) { picture in
      perform(SetMask(
        clipID: place.clip.id,
        index: index,
        width: max(abs(picture.x - mask.x) * 2, 0.01),
        height: max(abs(picture.y - mask.y) * 2, 0.01),
        at: isKeyframed ? place.playhead : nil,
      ))
    }
    if mask.shape == .path {
      ForEach(mask.points.indices, id: \.self) { point in
        MaskHandle(place: place, at: inPicture(mask.points[point]), isSmall: true) { picture in
          var points = mask.points
          points[point] = DrawingPoint(
            x: (picture.x - mask.x) / mask.width + 0.5,
            y: (picture.y - mask.y) / mask.height + 0.5,
          )
          perform(SetMask(
            clipID: place.clip.id,
            index: index,
            points: points,
            at: isKeyframed ? place.playhead : nil,
          ))
        }
      }
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  /// The outline in picture fractions.
  private var outline: [CGPoint] {
    switch mask.shape {
    case .rectangle:
      [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map { corner in
        CGPoint(x: mask.x + corner.0 * mask.width / 2, y: mask.y + corner.1 * mask.height / 2)
      }

    case .ellipse:
      (0 ..< 48).map { step in
        let angle = Double(step) / 48 * 2 * .pi
        return CGPoint(
          x: mask.x + cos(angle) * mask.width / 2,
          y: mask.y + sin(angle) * mask.height / 2,
        )
      }

    case .path:
      mask.points.map(inPicture)
    }
  }

  /// A point of the mask's box (fractions of it) in picture fractions.
  private func inPicture(_ point: DrawingPoint) -> CGPoint {
    CGPoint(
      x: mask.x + (point.x - 0.5) * mask.width,
      y: mask.y + (point.y - 0.5) * mask.height,
    )
  }

  private func perform(_ command: SetMask) {
    do {
      try editor.perform(command, coalescing: "\(place.clip.id).mask\(index)")
    } catch {
      onError(error.errorDescription ?? "The mask couldn't be changed.")
    }
  }

}

// MARK: - MaskHandle

/// A round handle at a point of the picture that reports where in the picture it's dragged.
private struct MaskHandle: View {

  // MARK: Internal

  let place: MaskPlacement
  /// Where it sits, in picture fractions.
  let at: CGPoint
  /// Marks the centre that moves the whole mask.
  var isCentre = false
  /// A path's point, drawn smaller.
  var isSmall = false
  let onDrag: (CGPoint) -> Void

  var body: some View {
    Circle()
      .fill(.white)
      .overlay {
        if isCentre {
          Image(systemName: "plus")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.black)
        }
      }
      .frame(width: isSmall ? 6 : 10, height: isSmall ? 6 : 10)
      .position(place.viewPoint(at))
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .named(MaskPlacement.space))
          .onChanged { onDrag(place.picturePoint($0.location)) }
          .onEnded { _ in editor.endCoalescing() }
      )
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
