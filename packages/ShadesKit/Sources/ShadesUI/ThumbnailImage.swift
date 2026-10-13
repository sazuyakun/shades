import ShadesMedia
import SwiftUI

/// A still frame from a media file, loaded in the background.
struct ThumbnailImage: View {
  let url: URL

  var body: some View {
    ZStack {
      Color.black
      if let image {
        Image(decorative: image, scale: 1)
          .resizable()
          .scaledToFill()
      }
    }
    .clipped()
    .task(id: url) {
      // why: a missing thumbnail just shows black; the failure is already logged by ShadesMedia.
      image = try? await MediaLoader.thumbnail(for: url, maxSize: CGSize(width: 320, height: 320))
    }
  }

  @State private var image: CGImage?
}
