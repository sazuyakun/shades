import ShadesCore
import SwiftUI

/// How a clip looks: rounded, labeled, with a thumbnail like Final Cut's filmstrip (video) or a
/// sound color (audio). Outlined in the accent color when selected, glowing purple for a moment
/// after Claude changes it.
struct TimelineClipView: View {
  let media: Media?
  let isAudio: Bool
  let isSelected: Bool
  let isRecentlyChanged: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(isAudio ? Theme.audioClip : Theme.videoClip)
      .overlay(alignment: .leading) {
        if let media, !isAudio, media.hasVideo {
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
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(
            isSelected ? Color.accentColor : .white.opacity(0.08),
            lineWidth: isSelected
              ? 2
              : 1,
          )
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
