import ShadesCore
import ShadesMedia
import SwiftUI

/// A video clip's frames side by side across its width, like Final Cut's filmstrip: each tile
/// shows the frame playing under it on the timeline, so speed ramps and split pieces read right.
struct ClipFilmstrip: View {

  // MARK: Internal

  let url: URL
  let clip: Clip

  var body: some View {
    GeometryReader { geometry in
      let tileWidth = geometry.size.height * 16 / 9
      let needed = Int((geometry.size.width / tileWidth).rounded(.up))
      let count = Self.tileCounts.first { $0 >= needed } ?? Self.tileCounts.last ?? 1
      HStack(spacing: 0) {
        ForEach(frames.indices, id: \.self) { index in
          Image(decorative: frames[index], scale: 1)
            .resizable()
            .scaledToFill()
            .frame(width: max(tileWidth, geometry.size.width / Double(frames.count)))
            .clipped()
        }
      }
      .frame(width: geometry.size.width, alignment: .leading)
      .clipped()
      .task(id: seconds(count: count)) {
        // why: zooming and trimming change the tiles many times a second; load once they settle.
        try? await Task.sleep(for: Self.settleDelay)
        guard !Task.isCancelled else {
          return
        }
        // why: a filmstrip that didn't load leaves the clip's own colour; failures are logged.
        if
          let loaded = try? await MediaLoader.frames(
            of: url,
            at: seconds(count: count),
            maxSize: CGSize(width: 192, height: 108),
          )
        {
          frames = loaded
        }
      }
    }
  }

  // MARK: Private

  /// How many tiles a clip can have: steps, so zooming reloads rarely, up to enough for a clip
  /// as wide as the window; past that the tiles stretch, keeping memory low.
  private static let tileCounts = [1, 2, 4, 8, 16, 24]
  /// How long the tiles must stay the same before their frames load.
  private static let settleDelay = Duration.milliseconds(300)

  @State private var frames = [CGImage]()

  /// Where in the media each of `count` tiles comes from: the middle of its stretch of the clip.
  private func seconds(count: Int) -> [Double] {
    (0 ..< count).map { index in
      let fraction = (Double(index) + 0.5) / Double(count)
      let time = clip.timelineStart.seconds + clip.duration.seconds * fraction
      return clip.sourceTime(at: MediaTime(seconds: time)).seconds
    }
  }

}
