import ShadesCommands
import ShadesCore
import SwiftUI

/// A track's slim header: its label and mute (audio) or hide (video) switch.
struct TrackHeader: View {

  // MARK: Internal

  let track: Track
  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 4) {
      Text(editor.project.timeline.label(of: track))
        .font(.caption.weight(.semibold))
      Spacer()
      Button {
        toggle()
      } label: {
        Image(systemName: icon)
          .font(.system(size: 10))
          .foregroundStyle(isOff ? Theme.negative : Theme.faintText)
      }
      .buttonStyle(.plain)
      .help(track.kind == .audio ? "Mute or unmute this track" : "Hide or show this track")
    }
    .padding(.horizontal, 10)
    .frame(width: TimelinePane.headerWidth)
    .frame(maxHeight: .infinity)
    .background(Theme.background)
    .overlay(alignment: .trailing) { Hairline(vertical: true) }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

  private var isOff: Bool {
    track.kind == .audio ? track.isMuted : track.isHidden
  }

  private var icon: String {
    switch (track.kind == .audio, isOff) {
    case (false, false): "eye"
    case (false, true): "eye.slash"
    case (true, false): "speaker.wave.2"
    case (true, true): "speaker.slash"
    }
  }

  private func toggle() {
    let label = editor.project.timeline.label(of: track)
    do {
      if track.kind != .audio {
        try editor.perform(SetTrack(track: label, hidden: !track.isHidden))
      } else {
        try editor.perform(SetTrack(track: label, muted: !track.isMuted))
      }
    } catch {
      onError(error.errorDescription ?? "The track couldn't be changed.")
    }
  }

}
