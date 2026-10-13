import ShadesCore
import SwiftUI

/// One clip on a track: rounded, labeled, with a thumbnail like Final Cut's filmstrip.
struct TimelineClipView: View {
  let media: Media?

  var body: some View {
    RoundedRectangle(cornerRadius: 5)
      .fill(Theme.videoClip)
      .overlay(alignment: .leading) {
        if let media {
          ThumbnailImage(url: media.url)
            .frame(width: 90)
            .padding(.top, 16)
            .padding(.bottom, 3)
        }
      }
      .overlay(alignment: .topLeading) {
        Text(media?.name ?? "Missing media")
          .font(.caption2)
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.horizontal, 6)
          .padding(.top, 2)
      }
      .clipShape(.rect(cornerRadius: 5))
      .overlay {
        RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.12))
      }
  }
}
