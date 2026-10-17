import ShadesCore
import SwiftUI

/// One clip in the media browser: its thumbnail, name and length.
struct MediaTile: View {
  let media: Media
  let isSelected: Bool

  var body: some View {
    ThumbnailImage(url: media.url)
      .aspectRatio(16 / 10, contentMode: .fit)
      .overlay(alignment: .bottom) {
        HStack {
          Text(media.name).lineLimit(1)
          Spacer()
          Text(Timecode.short(media.duration.seconds))
        }
        .font(.caption)
        .foregroundStyle(.white)
        .shadow(color: .black, radius: 3)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
      }
      .clipShape(.rect(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(
            isSelected ? Color.accentColor : Theme.strongHairline,
            lineWidth: isSelected
              ? 2
              : 1,
          )
      }
  }
}
