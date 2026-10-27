import ShadesCore
import SwiftUI

/// How a clip looks: rounded, labeled, with a filmstrip like Final Cut's (video), a
/// sound color (audio) or its words (text), diamonds where it has keyframes, and a chain when
/// it's linked to clips on other tracks (a video and its sound). Outlined in the
/// accent color when selected, glowing purple for a moment after Claude changes it.
struct TimelineClipView: View {

  // MARK: Internal

  let clip: Clip
  let media: Media?
  let text: String?
  let kind: TrackKind
  let isSelected: Bool
  let isRecentlyChanged: Bool
  /// Whether it moves, trims and splits with clips on other tracks.
  let isLinked: Bool
  /// Where the clip has keyframes, as fractions of its length.
  let keyframeSpots: [Double]
  /// The waveform of the stretch of sound the clip plays, when it's been drawn.
  let peaks: [Float]?

  var body: some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(color)
      .overlay {
        if let media, kind == .video, media.hasVideo {
          ClipFilmstrip(url: media.url, clip: clip)
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
        HStack(spacing: 4) {
          if isLinked {
            Image(systemName: "link")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundStyle(.white.opacity(0.85))
              .help("Linked: moves, trims and splits with its video or sound (⇧⌘L unlinks)")
          }
          Text(text ?? media?.name ?? "Missing media")
            .font(.system(size: 10.5))
            .foregroundStyle(.white)
            .lineLimit(1)
          if let color = media?.color, let conversion = color.conversion {
            Text(color.isHDR ? "HDR" : "Wide")
              .font(.system(size: 8.5, weight: .bold))
              .foregroundStyle(.white.opacity(0.85))
              .padding(.horizontal, 4)
              .background(.black.opacity(0.3), in: .capsule)
              .help(conversion)
          }
        }
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
