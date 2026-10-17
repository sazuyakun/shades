import Foundation
import ShadesCore
import Testing

struct SpokenWordTests {

  // MARK: Internal

  @Test
  func `words inside a clip are moved to timeline time`() {
    // The clip plays source 10–14 s at timeline 2–6 s.
    let clip = Clip(
      mediaID: mediaID,
      sourceStart: seconds(10),
      duration: seconds(4),
      timelineStart: seconds(2),
    )
    let timeline = Timeline(tracks: [Track(kind: .video, clips: [clip])])
    let words = timeline.spokenWords(transcripts: [mediaID: transcript])
    #expect(words.map(\.text) == ["inside", "edge"])
    #expect(words[0].start == seconds(3))
    #expect(words.allSatisfy { $0.clipID == clip.id })
  }

  @Test
  func `muted tracks and detached sound are silent`() {
    var clip = Clip(
      mediaID: mediaID,
      sourceStart: .zero,
      duration: seconds(20),
      timelineStart: .zero,
    )
    clip.isAudioEnabled = false
    let detached = Timeline(tracks: [Track(kind: .video, clips: [clip])])
    #expect(detached.spokenWords(transcripts: [mediaID: transcript]).isEmpty)
    clip.isAudioEnabled = true
    let muted = Timeline(tracks: [Track(kind: .video, clips: [clip], isMuted: true)])
    #expect(muted.spokenWords(transcripts: [mediaID: transcript]).isEmpty)
  }

  // MARK: Private

  private let mediaID = UUID()

  private var transcript: Transcript {
    let words = [("before", 5.0), ("inside", 11.0), ("edge", 13.5), ("after", 14.5)]
      .map { text, start in
        TranscriptWord(text: text, start: seconds(start), end: seconds(start + 0.4))
      }
    return Transcript(
      segments: [TranscriptSegment(text: "", start: seconds(5), end: seconds(15), words: words)],
      language: "en",
    )
  }

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

}
