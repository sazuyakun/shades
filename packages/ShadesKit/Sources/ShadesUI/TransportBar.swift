import ShadesCommands
import ShadesEngine
import SwiftUI

/// The round play/pause button and the playhead's timecode, under the viewer.
struct TransportBar: View {

  // MARK: Internal

  var body: some View {
    HStack(spacing: 14) {
      Button {
        player.togglePlayback()
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(Theme.background)
          .frame(width: 30, height: 30)
          .background(Theme.text, in: .circle)
      }
      .buttonStyle(.plain)
      .help("Play or pause (Space)")
      TimecodeText(
        seconds: player.currentTime,
        framesPerSecond: editor.project.timeline.format.framesPerSecond,
      )
    }
    .frame(maxWidth: .infinity)
    .frame(height: 46)
  }

  // MARK: Private

  @Environment(Player.self) private var player
  @Environment(Editor.self) private var editor

}
