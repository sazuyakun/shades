import ShadesEngine
import SwiftUI

/// Live frames-per-second and memory use, shown over the viewer.
struct PerformanceHUD: View {
  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      let megabytes = SystemStats.residentMemoryBytes() / 1_048_576
      Text("\(player.frameCounter.framesPerSecond) fps · \(megabytes) MB")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(Theme.secondaryText)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 4))
    }
  }

  @Environment(Player.self) private var player
}
