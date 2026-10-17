import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// One track: its header (kept in view while scrolling sideways) and its lane of clips. Clicking
/// empty lane deselects and moves the playhead.
struct TrackRow: View {

  // MARK: Internal

  let track: Track
  /// Every row top to bottom, for moving clips between tracks.
  let rows: [Track]
  let scale: TimelineScale
  let settings: TimelineSettings
  /// How far the timeline is scrolled sideways, to keep the header in view.
  let headerOffset: Double
  let onError: (String) -> Void

  var body: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: TimelinePane.headerWidth)
      ZStack(alignment: .topLeading) {
        Color.clear
          .contentShape(.rect)
          .onTapGesture { location in
            editor.selection = []
            Task { await player.seek(toSeconds: scale.seconds(atX: location.x)) }
          }
        ForEach(track.clips) { clip in
          TimelineClip(
            clip: clip,
            track: track,
            rows: rows,
            scale: scale,
            settings: settings,
            onError: onError,
          )
        }
      }
    }
    .frame(height: Self.height(of: track))
    .overlay(alignment: .leading) {
      TrackHeader(track: track, onError: onError)
        .offset(x: headerOffset)
    }
    .overlay(alignment: .bottom) { Hairline() }
  }

  /// How tall a track's row is: video tallest for its filmstrip, text slimmest.
  static func height(of track: Track) -> Double {
    switch track.kind {
    case .video: 72
    case .audio: 48
    case .text: 36
    }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

}
