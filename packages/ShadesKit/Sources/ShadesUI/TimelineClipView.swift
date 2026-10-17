import ShadesCore
import SwiftUI

/// One clip on a track: rounded, labeled, with a thumbnail like Final Cut's filmstrip. Glows
/// purple for a moment after Claude changes it.
struct TimelineClipView: View {
  let media: Media?
  let isRecentlyChanged: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(Theme.videoClip)
      .overlay(alignment: .leading) {
        if let media {
          ThumbnailImage(url: media.url)
            .frame(width: 90)
            .padding(.top, 17)
            .padding(.bottom, 4)
        }
      }
      .overlay(alignment: .topLeading) {
        Text(media?.name ?? "Missing media")
          .font(.system(size: 10.5))
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.horizontal, 7)
          .padding(.top, 2)
      }
      .clipShape(.rect(cornerRadius: 7))
      .overlay {
        RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.08))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(Theme.claude, lineWidth: 2)
          .shadow(color: Theme.claude, radius: 8)
          .opacity(isRecentlyChanged ? 1 : 0)
      }
      .animation(.easeOut(duration: 0.6), value: isRecentlyChanged)
  }
}
