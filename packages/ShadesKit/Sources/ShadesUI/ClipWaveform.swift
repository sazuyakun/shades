import SwiftUI

/// A clip's sound as a mirrored waveform, one bar every 2 points, each the loudest peak under it.
struct ClipWaveform: View {
  let peaks: [Float]

  var body: some View {
    Canvas { context, size in
      guard !peaks.isEmpty else {
        return
      }
      let bars = max(Int(size.width / 2), 1)
      var path = Path()
      for bar in 0 ..< bars {
        let first = bar * peaks.count / bars
        let last = max((bar + 1) * peaks.count / bars, first + 1)
        let peak = CGFloat(peaks[first ..< min(last, peaks.count)].max() ?? 0)
        let height = max(peak * size.height, 1)
        path.addRect(CGRect(
          x: CGFloat(bar) * 2,
          y: (size.height - height) / 2,
          width: 1.5,
          height: height,
        ))
      }
      context.fill(path, with: .color(.white.opacity(0.55)))
    }
  }
}
