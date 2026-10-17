import ShadesCaptions
import ShadesCommands
import ShadesCore
import ShadesEngine
import SwiftUI

/// What's said on the timeline, as text: click a word to jump there, shift-click to select a
/// run of words, and cut them to edit by text. Transcribe and add captions from here too.
struct TranscriptPane: View {

  // MARK: Internal

  let onError: (String) -> Void

  var body: some View {
    let words = editor.project.timeline.spokenWords(transcripts: workspace.analysis.transcripts)
    VStack(alignment: .leading, spacing: 0) {
      SectionLabel(title: "Transcript", detail: words.isEmpty ? nil : "\(words.count) words")
      HStack(spacing: 6) {
        Button("Transcribe") { transcribe() }
          .help("Transcribe the clips on the timeline that have no transcript yet")
        Button("Add Captions") { addCaptions() }
          .disabled(words.isEmpty)
        Spacer()
        Button("Cut Words") { cut(words) }
          .disabled(selection.isEmpty)
          .help("Remove the selected words from the timeline, closing the gap")
      }
      .buttonStyle(CapsuleButtonStyle())
      .padding(.horizontal, 14)
      .padding(.bottom, 10)
      Hairline()
      if words.isEmpty {
        Text("Transcribe the clips to see what's said, edit it as text and add captions.")
          .font(.callout)
          .foregroundStyle(Theme.faintText)
          .padding(14)
        Spacer()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(lines(of: words), id: \.first) { indices in
              TranscriptLine(
                words: words,
                indices: indices,
                selection: selection,
                playhead: MediaTime(seconds: player.currentTime),
                onTap: { tap($0, in: words) },
              )
            }
          }
          .padding(14)
        }
      }
    }
    .background(Theme.background)
  }

  // MARK: Private

  @Environment(Workspace.self) private var workspace
  @Environment(Editor.self) private var editor
  @Environment(Player.self) private var player
  @State private var selection = Set<Int>()
  @State private var anchor: Int?

  /// Word indices grouped into caption-sized lines.
  private func lines(of words: [SpokenWord]) -> [[Int]] {
    var index = 0
    return CaptionLayout.lines(for: words).map { line in
      let count = line.text.split(separator: " ").count
      defer { index += count }
      return Array(index ..< min(index + count, words.count))
    }
  }

  private func tap(_ index: Int, in words: [SpokenWord]) {
    if NSEvent.modifierFlags.contains(.shift), let anchor {
      selection = Set(min(anchor, index) ... max(anchor, index))
    } else {
      selection = [index]
      anchor = index
      Task { await player.seek(toSeconds: words[index].start.seconds) }
    }
  }

  private func transcribe() {
    let queued = workspace.transcribe(nil, model: .small, language: nil)
    if queued.isEmpty {
      onError("Every clip with sound on the timeline already has a transcript.")
    }
  }

  private func addCaptions() {
    do {
      _ = try workspace.addCaptions(in: nil)
    } catch {
      onError(error.errorDescription ?? "Captions couldn't be added.")
    }
  }

  /// Removes the selected words' time from their track, closing the gap.
  private func cut(_ words: [SpokenWord]) {
    let chosen = selection.sorted().filter { words.indices.contains($0) }.map { words[$0] }
    guard
      let first = chosen.first,
      let location = editor.project.timeline.location(ofClip: first.clipID)
    else {
      return
    }
    let track = editor.project.timeline.label(of: editor.project.timeline.tracks[location.track])
    do {
      try editor.perform(RemoveRanges(
        ranges: chosen.map { TimeRange(start: $0.start, end: $0.end) },
        track: track,
      ))
      selection = []
    } catch {
      onError(error.errorDescription ?? "The words couldn't be cut.")
    }
  }

}
