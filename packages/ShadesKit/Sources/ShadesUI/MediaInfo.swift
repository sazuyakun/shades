import ShadesCore
import SwiftUI

/// A media file's name, length, size and audio, as rows in the inspector.
struct MediaInfo: View {
  let media: Media

  var body: some View {
    Grid(alignment: .leading, verticalSpacing: 8) {
      GridRow {
        Text("Name").foregroundStyle(Theme.secondaryText)
        Text(media.name)
      }
      GridRow {
        Text("Duration").foregroundStyle(Theme.secondaryText)
        Text(Timecode.full(media.duration.seconds))
      }
      GridRow {
        Text("Size").foregroundStyle(Theme.secondaryText)
        Text("\(media.width) × \(media.height)")
      }
      GridRow {
        Text("Audio").foregroundStyle(Theme.secondaryText)
        Text(media.hasAudio ? "Yes" : "None")
      }
    }
  }
}
