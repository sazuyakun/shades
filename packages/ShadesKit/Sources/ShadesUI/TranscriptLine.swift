import ShadesCore
import SwiftUI

/// One caption-sized line of the transcript: its time and its words, the playing word lit.
struct TranscriptLine: View {
  let words: [SpokenWord]
  let indices: [Int]
  let selection: Set<Int>
  let playhead: MediaTime
  let onTap: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let first = indices.first {
        Text(Timecode.short(words[first].start.seconds))
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Theme.faintText)
      }
      WordFlow {
        ForEach(indices, id: \.self) { index in
          let word = words[index]
          let isPlaying = word.start <= playhead && playhead < word.end
          Text(word.text)
            .padding(.horizontal, 2)
            .background(
              selection.contains(index)
                ? Color.accentColor.opacity(0.45)
                : isPlaying ? Theme.pressed : .clear,
              in: .rect(cornerRadius: 3),
            )
            .contentShape(.rect)
            .onTapGesture { onTap(index) }
        }
      }
    }
  }
}
