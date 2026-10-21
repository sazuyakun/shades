import ShadesCommands
import ShadesEngine
import SwiftUI

/// The video viewer, with the performance HUD and transport underneath.
struct ViewerPane: View {

  // MARK: Internal

  let isDrawing: Bool
  let isTracking: Bool
  let onError: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      PlayerSurface(player: player.avPlayer)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay {
          if isDrawing {
            DrawingCanvas(onError: onError)
          } else if isTracking {
            TrackingCanvas(onError: onError)
          } else {
            MaskOverlay(onError: onError)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .overlay(alignment: .topLeading) {
          PerformanceHUD().padding(26)
        }
        .overlay(alignment: .topTrailing) {
          HStack(spacing: 6) {
            if player.isUsingProxies {
              Text("Proxy")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.raised, in: .capsule)
                .help("Playing light editing copies of heavy footage. Export uses the originals.")
            }
            PreviewQualityMenu()
          }
          .padding(26)
        }
      Hairline()
      TransportBar()
    }
    .background(Theme.viewer)
  }

  // MARK: Private

  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player

  /// The timeline's shape, so the viewer is exactly the picture with no black box around it.
  private var aspectRatio: Double {
    let format = editor.project.timeline.format
    return Double(format.width) / Double(format.height)
  }

}
