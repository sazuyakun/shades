import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// One track: its header (kept in view while scrolling sideways) and its lane of clips. Clicking
/// empty lane deselects and moves the playhead.
struct TrackRow: View {

  // MARK: Internal

  static let videoHeight = 72.0
  static let audioHeight = 48.0

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
    .frame(height: track.kind == .video ? Self.videoHeight : Self.audioHeight)
    .overlay(alignment: .leading) {
      TrackHeader(track: track, onError: onError)
        .offset(x: headerOffset)
    }
    .overlay(alignment: .bottom) { Hairline() }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

}
