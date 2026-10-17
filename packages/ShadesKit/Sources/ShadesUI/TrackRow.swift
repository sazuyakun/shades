import ShadesCommands
import ShadesCore
import ShadesMCP
import SwiftUI

/// A track's slim header ("V1") and its lane of clips, with a hairline below.
struct TrackRow: View {

  // MARK: Internal

  let track: Track
  let scale: TimelineScale

  var body: some View {
    HStack(spacing: 0) {
      Text(track.name)
        .font(.caption.weight(.semibold))
        .padding(.leading, 10)
        .frame(width: TimelinePane.headerWidth, alignment: .leading)
        .frame(maxHeight: .infinity)
      Hairline(vertical: true)
      ZStack(alignment: .leading) {
        ForEach(track.clips) { clip in
          TimelineClipView(
            media: editor.project.media(withID: clip.mediaID),
            isRecentlyChanged: server.activity.recentlyChangedClipIDs.contains(clip.id),
          )
          .frame(width: scale.x(atSeconds: clip.duration.seconds), height: 64)
          .offset(x: scale.x(atSeconds: clip.timelineStart.seconds))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 72)
    .overlay(alignment: .bottom) { Hairline() }
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(MCPServer.self) private var server

}
