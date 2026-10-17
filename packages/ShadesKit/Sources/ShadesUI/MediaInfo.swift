import ShadesCore
import SwiftUI

/// A media file's length, size and audio, as label / value-field rows in the inspector.
struct MediaInfo: View {
  let media: Media

  var body: some View {
    VStack(spacing: 10) {
      InspectorRow(label: "Duration", value: Timecode.full(media.duration.seconds))
      InspectorRow(label: "Size", value: "\(media.width)×\(media.height)")
      InspectorRow(label: "Audio", value: media.hasAudio ? "Yes" : "None")
    }
  }
}
