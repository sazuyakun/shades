import Foundation
import ShadesCore
import Synchronization

// MARK: - RenderState

/// How every clip is drawn right now. The compositor reads it for each frame, so changing a
/// clip's position, opacity, keyframes or a track's visibility shows at once, without rebuilding
/// playback.
public final class RenderState: Sendable {

  // MARK: Lifecycle

  public init() { }

  // MARK: Internal

  /// Takes the current look of every clip from the timeline.
  func update(from timeline: Timeline) {
    var styles = [Clip.ID: LayerStyle]()
    for track in timeline.tracks where track.kind != .audio {
      for clip in track.clips {
        styles[clip.id] = LayerStyle(clip: clip, isVisible: !track.isHidden)
      }
    }
    self.styles.withLock { $0 = styles }
  }

  /// How the clip is drawn, if it's on the timeline.
  func style(of clipID: Clip.ID) -> LayerStyle? {
    styles.withLock { $0[clipID] }
  }

  // MARK: Private

  private let styles = Mutex<[Clip.ID: LayerStyle]>([:])

}

// MARK: - LayerStyle

/// The look of one clip in the frame: the clip as it is now, and whether its track shows.
struct LayerStyle: Sendable {
  let clip: Clip
  let isVisible: Bool
}
