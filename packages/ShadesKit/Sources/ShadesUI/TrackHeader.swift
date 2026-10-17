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
      .help(track.kind == .video ? "Hide or show this track" : "Mute or unmute this track")
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
    track.kind == .video ? track.isHidden : track.isMuted
  }

  private var icon: String {
    switch (track.kind, isOff) {
    case (.video, false): "eye"
    case (.video, true): "eye.slash"
    case (.audio, false): "speaker.wave.2"
    case (.audio, true): "speaker.slash"
    }
  }

  private func toggle() {
    let label = editor.project.timeline.label(of: track)
    do {
      if track.kind == .video {
        try editor.perform(SetTrack(track: label, hidden: !track.isHidden))
      } else {
        try editor.perform(SetTrack(track: label, muted: !track.isMuted))
      }
    } catch {
      onError(error.errorDescription ?? "The track couldn't be changed.")
    }
  }

}
