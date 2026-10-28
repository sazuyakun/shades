import ShadesAudio
import ShadesEngine
import SwiftUI

/// A stereo meter: a bar for each channel, filling from −60 dBFS to full scale, green, then
/// amber from −6 dB and red from −1 dB (where peaks clip once encoded).
struct LevelMeter: View {

  // MARK: Internal

  let level: MeterLevel?

  var body: some View {
    VStack(spacing: 2) {
      bar(level?.left ?? 0)
      bar(level?.right ?? 0)
    }
    .frame(height: 9)
  }

  // MARK: Private

  private static let floor = -60.0

  private func bar(_ value: Double) -> some View {
    let decibels = 20 * log10(max(value, 1e-6))
    let share = min(max((decibels - Self.floor) / -Self.floor, 0), 1)
    let color = decibels > -1 ? Theme.negative : decibels > -6 ? Theme.marker : Theme.positive
    return GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Theme.raised
        color.frame(width: geometry.size.width * share)
      }
    }
    .clipShape(.rect(cornerRadius: 1.5))
  }

}
