import ShadesCore
import SwiftUI

/// How a clip looks: rounded, labeled, with a thumbnail like Final Cut's filmstrip (video), a
/// sound color (audio) or its words (text), and diamonds where it has keyframes. Outlined in the
/// accent color when selected, glowing purple for a moment after Claude changes it.
struct TimelineClipView: View {

  // MARK: Internal

  let media: Media?
  let text: String?
  let kind: TrackKind
  let isSelected: Bool
  let isRecentlyChanged: Bool
  /// Where the clip has keyframes, as fractions of its length.
  let keyframeSpots: [Double]
  /// The waveform of the stretch of sound the clip plays, when it's been drawn.
  let peaks: [Float]?

  var body: some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(color)
      .overlay(alignment: .leading) {
        if let media, kind == .video, media.hasVideo {
          ThumbnailImage(url: media.url)
            .frame(width: 90)
            .padding(.top, 17)
            .padding(.bottom, 4)
        }
      }
      .overlay {
        if let peaks, kind == .audio {
          ClipWaveform(peaks: peaks)
            .padding(.top, 16)
            .padding(.bottom, 3)
        }
      }
      .overlay(alignment: .topLeading) {
        Text(text ?? media?.name ?? "Missing media")
          .font(.system(size: 10.5))
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.horizontal, 7)
          .padding(.top, 2)
      }
      .overlay {
        GeometryReader { geometry in
          ForEach(keyframeSpots, id: \.self) { spot in
            Image(systemName: "diamond.fill")
              .font(.system(size: 7))
              .foregroundStyle(.white)
              .position(x: spot * geometry.size.width, y: geometry.size.height - 6)
          }
        }
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

  // MARK: Private

  private var color: Color {
    switch kind {
    case .video: Theme.videoClip
    case .audio: Theme.audioClip
    case .text: Theme.textClip
    }
  }

}
