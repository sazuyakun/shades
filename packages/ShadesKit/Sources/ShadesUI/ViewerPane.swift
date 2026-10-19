import ShadesCommands
import ShadesEngine
import SwiftUI

/// The video viewer, with the performance HUD and transport underneath.
struct ViewerPane: View {

  // MARK: Internal

  let isDrawing: Bool
  let onError: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      PlayerSurface(player: player.avPlayer)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay {
          if isDrawing {
            DrawingCanvas(onError: onError)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .overlay(alignment: .topLeading) {
          PerformanceHUD().padding(26)
        }
        .overlay(alignment: .topTrailing) {
          if player.isUsingProxies {
            Text("Proxy")
              .font(.system(size: 10.5, weight: .semibold))
              .foregroundStyle(Theme.secondaryText)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Theme.raised, in: .capsule)
              .padding(26)
              .help("Playing light editing copies of heavy footage. Export uses the originals.")
          }
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
