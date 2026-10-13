import ShadesEngine
import SwiftUI

/// The video viewer, with the performance HUD and transport underneath.
struct ViewerPane: View {
  var body: some View {
    VStack(spacing: 0) {
      PlayerSurface(player: player.avPlayer)
        .overlay(alignment: .topLeading) {
          PerformanceHUD().padding(8)
        }
      TransportBar()
    }
    .background(Theme.viewer)
  }

  @Environment(Player.self) private var player
}
