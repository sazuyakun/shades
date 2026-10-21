import ShadesCommands
import ShadesCore
import SwiftUI

/// A track's slim header: its label, a hide switch for pictures (video and text) and a mute
/// switch for sound (audio, and video whose clips play their own).
struct TrackHeader: View {

  // MARK: Internal

  let track: Track
  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(label)
        .font(.caption.weight(.semibold))
      Spacer()
      if editor.project.hasSound(track) {
        toggle(
          icon: track.isMuted ? "speaker.slash" : "speaker.wave.2",
          isOff: track.isMuted,
          help: "Mute or unmute this track's sound",
        ) { SetTrack(track: label, muted: !track.isMuted) }
      }
      if track.kind != .audio {
        toggle(
          icon: track.isHidden ? "eye.slash" : "eye",
          isOff: track.isHidden,
          help: "Hide or show this track",
        ) { SetTrack(track: label, hidden: !track.isHidden) }
      }
    }
    .padding(.horizontal, 10)
    .frame(width: TimelinePane.headerWidth)
    .frame(maxHeight: .infinity)
    .background(Theme.background)
    .overlay(alignment: .trailing) { Hairline(vertical: true) }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private var label: String {
    editor.project.timeline.label(of: track)
  }

  private func toggle(
    icon: String,
    isOff: Bool,
    help: String,
    command: @escaping () -> SetTrack,
  ) -> some View {
    Button {
      do throws(CommandError) {
        try editor.perform(command())
      } catch {
        onError(error.errorDescription ?? "The track couldn't be changed.")
      }
    } label: {
      Image(systemName: icon)
        .font(.system(size: 10))
        .foregroundStyle(isOff ? Theme.negative : Theme.faintText)
    }
    .buttonStyle(.plain)
    .help(help)
  }

}
