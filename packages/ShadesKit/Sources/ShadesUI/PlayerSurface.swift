import AVKit
import SwiftUI

/// Shows the player's frames. AppKit's AVPlayerView, wrapped for SwiftUI.
struct PlayerSurface: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context _: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = player
    view.controlsStyle = .none
    view.videoGravity = .resizeAspect
    return view
  }

  func updateNSView(_ view: AVPlayerView, context _: Context) {
    view.player = player
  }
}
