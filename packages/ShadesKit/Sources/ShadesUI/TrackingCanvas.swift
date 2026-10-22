import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// The Track tool over the viewer: drag a box around something in a video and Shades follows it
/// from the playhead to the clip's end, in the background, as a path layers can follow.
struct TrackingCanvas: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      Rectangle()
        .strokeBorder(Theme.text, lineWidth: 1.5)
        .frame(width: box.width * size.width, height: box.height * size.height)
        .offset(x: box.minX * size.width, y: box.minY * size.height)
        .opacity(box.isEmpty ? 0 : 1)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .contentShape(.rect)
        .gesture(DragGesture(minimumDistance: 2).onChanged { drag in
          let start = fraction(of: drag.startLocation, in: size)
          let end = fraction(of: drag.location, in: size)
          box = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y),
          )
        }.onEnded { _ in
          track(box)
          box = .zero
        })
    }
    .overlay(Rectangle().strokeBorder(
      Theme.secondaryText.opacity(0.6),
      style: StrokeStyle(lineWidth: 1, dash: [4, 4]),
    ))
    .help("Track Tool (⌥T): drag a box around something in the video to follow it. "
      + "Press ⌥T again to stop.")
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @Environment(Workspace.self) private var workspace
  @State private var box = CGRect.zero

  private func fraction(of location: CGPoint, in size: CGSize) -> CGPoint {
    CGPoint(
      x: min(max(location.x / max(size.width, 1), 0), 1),
      y: min(max(location.y / max(size.height, 1), 0), 1),
    )
  }

  /// Follows what's in `box` through the selected video at the playhead, or else the topmost
  /// video there.
  private func track(_ box: CGRect) {
    let project = editor.project
    let playhead = MediaTime(seconds: player.currentTime)
      .roundedToFrame(at: project.timeline.format.framesPerSecond)
    let showing = project.timeline.tracks.reversed().filter { $0.kind == .video }
      .compactMap { $0.clip(at: playhead) }
      .filter { clip in
        clip.mediaID.flatMap(project.media(withID:)).map { $0.hasVideo && !$0.isStill } == true
      }
    guard
      let clip = showing.first(where: { editor.selection.contains($0.id) }) ?? showing.first,
      let media = clip.mediaID.flatMap(project.media(withID:))
    else {
      onError("Move the playhead over a video clip, then draw the box around what to follow.")
      return
    }
    // why: no GPU means no frames to track in either; the box just finds no picture.
    let projection = try? player.renderContext().projection(of: clip, in: project, at: playhead)
    let picture = projection?.pictureBox(under: box) ?? .zero
    guard !picture.isEmpty else {
      onError("Draw the box over the video's picture.")
      return
    }
    let count = workspace.analysis.analyses[media.id]?.tracks?.count ?? 0
    do {
      _ = try workspace.trackMotion(
        clipID: clip.id,
        at: playhead,
        box: picture,
        name: "Box \(count + 1)",
      )
    } catch {
      onError(error.errorDescription ?? "That couldn't be tracked.")
    }
  }

}
