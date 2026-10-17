import ShadesCommands
import ShadesEngine
import SwiftUI

/// The timeline: a title bar, the ruler, the tracks and the playhead. Click to move the playhead.
struct TimelinePane: View {

  // MARK: Internal

  /// Width of the track headers on the left.
  static let headerWidth: Double = 76

  var body: some View {
    VStack(spacing: 0) {
      Hairline()
      TimelineTitleBar()
      Hairline()
      GeometryReader { geometry in
        let scale = TimelineScale(
          width: geometry.size.width - Self.headerWidth - 1,
          duration: player.duration,
        )
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            Color.clear.frame(width: Self.headerWidth)
            Hairline(vertical: true)
            TimelineRuler(scale: scale)
          }
          .frame(height: 24)
          .overlay(alignment: .bottom) { Hairline() }
          ForEach(editor.project.timeline.tracks) { track in
            TrackRow(track: track, scale: scale)
          }
          Spacer()
        }
        .overlay(alignment: .topLeading) {
          Playhead()
            .offset(x: Self.headerWidth + 1 + scale.x(atSeconds: player.currentTime) - 6)
        }
        .contentShape(.rect)
        .onTapGesture { location in
          let seconds = scale.seconds(atX: location.x - Self.headerWidth - 1)
          Task { await player.seek(toSeconds: seconds) }
        }
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

}
