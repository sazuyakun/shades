import ShadesEngine
import SwiftUI

/// Live playback and process numbers over the viewer: frames a second, frames dropped while
/// playing, how long a frame takes to draw, how long the last scrub and edit waited for their
/// frame, CPU and memory.
struct PerformanceHUD: View {

  // MARK: Internal

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      let frames = player.frameCounter
      let megabytes = SystemStats.residentMemoryBytes() / 1_048_576
      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: "\(frames.framesPerSecond) fps · \(frames.droppedFrames) dropped · "
          + "\(milliseconds(frames.frameTime)) a frame")
        Text(verbatim: "scrub \(milliseconds(frames.scrubLatency)) · edit "
          + "\(milliseconds(frames.editLatency)) · CPU \(Int(cpu.usage().rounded()))% · "
          + "\(megabytes) MB")
      }
      .font(.system(size: 10.5, design: .monospaced))
      .foregroundStyle(Theme.secondaryText)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(.black.opacity(0.45), in: .rect(cornerRadius: 6))
    }
  }

  // MARK: Private

  @Environment(Player.self) private var player
  @State private var cpu = CPUMeter()

  /// `duration` in whole milliseconds, or a dash before there's one.
  private func milliseconds(_ duration: Duration?) -> String {
    guard let duration else {
      return "–"
    }
    let (seconds, attoseconds) = duration.components
    return "\(Int((Double(seconds) * 1000 + Double(attoseconds) * 1e-15).rounded())) ms"
  }

}
