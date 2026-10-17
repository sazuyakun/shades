import ShadesEngine
import SwiftUI

/// Live frames-per-second and memory use, shown over the viewer.
struct PerformanceHUD: View {
  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      let megabytes = SystemStats.residentMemoryBytes() / 1_048_576
      Text(verbatim: "\(player.frameCounter.framesPerSecond) fps · \(megabytes) MB")
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(Theme.secondaryText)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.black.opacity(0.45), in: .rect(cornerRadius: 6))
    }
  }

  @Environment(Player.self) private var player
}
