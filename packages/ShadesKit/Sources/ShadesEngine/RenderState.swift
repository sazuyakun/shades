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
        styles[clip.id] = LayerStyle(
          clip: clip,
          isVisible: !track.isHidden,
          followsCamera: track.followsCamera,
        )
      }
    }
    self.styles.withLock { $0 = styles }
    camera.withLock { $0 = timeline.camera }
    shutterLength.withLock {
      $0 = timeline.shutterAngle / 360 / Double(timeline.format.framesPerSecond)
    }
  }

  /// Where the timeline's camera is at `time`.
  func camera(at time: MediaTime) -> ClipTransform {
    camera.withLock { $0 }.transform(at: time, fixed: .identity)
  }

  /// How long the shutter is open each frame, in seconds: how far back and on moving layers blur.
  func shutter() -> Double {
    shutterLength.withLock { $0 }
  }

  /// How the clip is drawn, if it's on the timeline.
  func style(of clipID: Clip.ID) -> LayerStyle? {
    styles.withLock { $0[clipID] }
  }

  // MARK: Private

  private let styles = Mutex<[Clip.ID: LayerStyle]>([:])
  private let camera = Mutex<[Keyframe]>([])
  private let shutterLength = Mutex<Double>(0)

}

// MARK: - LayerStyle

/// The look of one clip in the frame: the clip as it is now, whether its track shows, and
/// whether the camera moves it.
struct LayerStyle: Sendable {
  let clip: Clip
  let isVisible: Bool
  let followsCamera: Bool
}
