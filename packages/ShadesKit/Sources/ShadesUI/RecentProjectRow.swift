import ShadesDocument
import SwiftUI

/// One recent project: thumbnail, name and when it last changed.
struct RecentProjectRow: View {
  let entry: LibraryEntry

  var body: some View {
    HStack(spacing: 12) {
      Group {
        if let thumbnail = ProjectFile.thumbnailURL(of: entry.url) {
          AsyncImage(url: thumbnail) { image in
            image.resizable().scaledToFill()
          } placeholder: {
            Theme.raised
          }
        } else {
          Theme.raised
        }
      }
      .frame(width: 72, height: 54)
      .clipShape(.rect(cornerRadius: 6))
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.name)
          .font(.callout.weight(.medium))
          .lineLimit(1)
        Text(entry.modified, format: .relative(presentation: .named))
          .font(.caption)
          .foregroundStyle(Theme.faintText)
      }
      Spacer()
    }
    .padding(6)
  }
}
