import ShadesCore
import ShadesMedia
import SwiftUI

/// One clip in the media browser: its thumbnail, name and length. Moving the pointer across it
/// scrubs through the clip; the part marked with I and O shows as a bar along the bottom.
struct MediaTile: View {

  // MARK: Internal

  let media: Media
  let isSelected: Bool
  let marks: SourceMarks?
  /// Reports the time under the pointer, or `nil` when it leaves.
  let onHover: (MediaTime?) -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottomLeading) {
        if let fraction = hoverFraction, !frames.isEmpty {
          let index = min(Int(fraction * Double(frames.count)), frames.count - 1)
          Image(decorative: frames[index], scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        } else if media.hasVideo {
          ThumbnailImage(url: media.url)
        } else {
          Theme.audioClip
            .overlay { Image(systemName: "waveform").foregroundStyle(.white.opacity(0.6)) }
        }
        if let marks {
          markBar(marks, width: geometry.size.width)
        }
        if let hoverFraction {
          Rectangle()
            .fill(Theme.text)
            .frame(width: 1.5)
            .offset(x: hoverFraction * geometry.size.width)
        }
      }
      .contentShape(.rect)
      .onContinuousHover { phase in
        switch phase {
        case .active(let location):
          let fraction = min(max(location.x / max(geometry.size.width, 1), 0), 1)
          hoverFraction = fraction
          onHover(MediaTime(seconds: media.duration.seconds * fraction))
          loadFilmstripIfNeeded()

        case .ended:
          hoverFraction = nil
          onHover(nil)
        }
      }
    }
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
      .allowsHitTesting(false)
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

  // MARK: Private

  /// Stills kept for scrubbing.
  private static let filmstripCount = 24

  @State private var hoverFraction: Double?
  @State private var frames = [CGImage]()
  @State private var isLoading = false

  private func markBar(_ marks: SourceMarks, width: Double) -> some View {
    let duration = max(media.duration.seconds, 0.001)
    let start = (marks.start?.seconds ?? 0) / duration
    let end = (marks.end?.seconds ?? duration) / duration
    return Rectangle()
      .fill(Color.accentColor)
      .frame(width: max((end - start) * width, 2), height: 3)
      .offset(x: start * width)
  }

  private func loadFilmstripIfNeeded() {
    guard media.hasVideo, frames.isEmpty, !isLoading else {
      return
    }
    isLoading = true
    Task {
      // why: no filmstrip just means hovering shows the still thumbnail; the failure is logged.
      frames = (try? await MediaLoader.filmstrip(
        for: media.url,
        count: Self.filmstripCount,
        maxSize: CGSize(width: 240, height: 240),
      )) ?? []
    }
  }

}
