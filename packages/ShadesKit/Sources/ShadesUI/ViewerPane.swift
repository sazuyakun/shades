import ShadesCommands
import ShadesEngine
import SwiftUI

/// The video viewer, with the performance HUD and transport underneath.
struct ViewerPane: View {

  // MARK: Internal

  var body: some View {
    VStack(spacing: 0) {
      PlayerSurface(player: player.avPlayer)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .overlay(alignment: .topLeading) {
          PerformanceHUD().padding(26)
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
