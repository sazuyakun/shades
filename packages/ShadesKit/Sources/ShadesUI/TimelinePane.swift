import ShadesCommands
import ShadesEngine
import SwiftUI

/// The timeline: a title bar, the ruler, the tracks and the playhead. Click to move the playhead.
struct TimelinePane: View {

  // MARK: Internal

  /// Width of the track headers on the left.
  static let headerWidth: Double = 70

  var body: some View {
    VStack(spacing: 0) {
      TimelineTitleBar()
      GeometryReader { geometry in
        let scale = TimelineScale(
          width: geometry.size.width - Self.headerWidth,
          duration: player.duration,
        )
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            Theme.trackHeader.frame(width: Self.headerWidth)
            TimelineRuler(scale: scale)
          }
          .frame(height: 24)
          ForEach(editor.project.timeline.tracks) { track in
            TrackRow(track: track, scale: scale)
          }
          Spacer()
        }
        .overlay(alignment: .topLeading) {
          Rectangle()
            .fill(.white)
            .frame(width: 1)
            .offset(x: Self.headerWidth + scale.x(atSeconds: player.currentTime))
        }
        .contentShape(.rect)
        .onTapGesture { location in
          let seconds = scale.seconds(atX: location.x - Self.headerWidth)
          Task { await player.seek(toSeconds: seconds) }
        }
      }
    }
    .background(Theme.timeline)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

}
