import ShadesCommands
import ShadesCore
import SwiftUI

/// A track's slim header ("V1") and its lane of clips.
struct TrackRow: View {

  // MARK: Internal

  let track: Track
  let scale: TimelineScale

  var body: some View {
    HStack(spacing: 0) {
      Text(track.name)
        .font(.caption.weight(.semibold))
        .frame(width: TimelinePane.headerWidth, alignment: .leading)
        .padding(.leading, 8)
        .frame(maxHeight: .infinity)
        .background(Theme.trackHeader)
      ZStack(alignment: .leading) {
        ForEach(track.clips) { clip in
          TimelineClipView(media: editor.project.media(withID: clip.mediaID))
            .frame(width: scale.x(atSeconds: clip.duration.seconds), height: 64)
            .offset(x: scale.x(atSeconds: clip.timelineStart.seconds))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 72)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor

}
