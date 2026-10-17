import SwiftUI

/// A large monospaced timecode whose leading zeros are dimmed, so the live digits stand out.
struct TimecodeText: View {
  let seconds: Double

  var body: some View {
    Text(styled)
      .font(.system(size: 17, weight: .medium, design: .monospaced))
  }

  private var styled: AttributedString {
    let timecode = Timecode.full(seconds)
    let liveStart = timecode.firstIndex { $0 != "0" && $0 != ":" } ?? timecode
      .index(before: timecode.endIndex)
    var dimmed = AttributedString(timecode[..<liveStart])
    dimmed.foregroundColor = Theme.faintText
    var live = AttributedString(timecode[liveStart...])
    live.foregroundColor = Theme.text
    return dimmed + live
  }
}
