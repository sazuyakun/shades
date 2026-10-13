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
        .font(.caption2)
        .foregroundStyle(.white)
        .shadow(radius: 2)
        .padding(5)
      }
      .clipShape(.rect(cornerRadius: 5))
      .overlay {
        RoundedRectangle(cornerRadius: 5)
          .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
      }
  }
}
