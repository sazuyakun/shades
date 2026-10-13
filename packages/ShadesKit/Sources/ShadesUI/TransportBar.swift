import ShadesEngine
import SwiftUI

/// Play/pause and the playhead's timecode, under the viewer.
struct TransportBar: View {
  var body: some View {
    HStack(spacing: 18) {
      Button {
        player.togglePlayback()
      } label: {
        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
          .frame(width: 20)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.space, modifiers: [])
      .help("Play or pause (Space)")
      Text(Timecode.full(player.currentTime))
        .font(.system(size: 18, weight: .medium, design: .monospaced))
    }
    .foregroundStyle(.white)
    .frame(height: 40)
  }

  @Environment(Player.self) private var player
}
