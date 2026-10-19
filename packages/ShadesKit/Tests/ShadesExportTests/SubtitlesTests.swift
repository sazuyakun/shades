import Foundation
import ShadesCore
import ShadesExport
import Testing

struct SubtitlesTests {

  @Test
  func `caption clips on the timeline become numbered srt lines`() throws {
    let word = TimedWord(text: "hello", start: .zero, end: MediaTime(seconds: 0.4))
    let caption = Clip(
      source: .text(TextContent(text: "hello there", words: [word])),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1.25),
      timelineStart: MediaTime(seconds: 61.5),
    )
    let title = Clip(
      source: .text(TextContent(text: "TITLE")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 2),
      timelineStart: .zero,
    )
    let timeline = Timeline(tracks: [
      Track(kind: .video),
      Track(kind: .text, clips: [title, caption]),
    ])
    let srt = try Subtitles.srt(of: timeline, transcripts: [:])
    #expect(srt == "1\n00:01:01,500 --> 00:01:02,750\nhello there\n")
  }

  @Test
  func `without captions, what's said is laid out into lines from the transcript`() throws {
    let media = Media(
      url: URL(filePath: "/tmp/talk.mov"),
      duration: MediaTime(seconds: 4),
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: media.duration,
      timelineStart: .zero,
    )
    let words = [
      TranscriptWord(text: "Hi", start: MediaTime(seconds: 0.5), end: MediaTime(seconds: 0.8)),
      TranscriptWord(text: "all.", start: MediaTime(seconds: 0.9), end: MediaTime(seconds: 1.2)),
    ]
    let transcript = Transcript(
      segments: [TranscriptSegment(
        text: "Hi all.",
        start: MediaTime(seconds: 0.5),
        end: MediaTime(seconds: 1.2),
        words: words,
      )],
      language: "en",
    )
    let timeline = Timeline(tracks: [Track(kind: .video, clips: [clip])])
    let srt = try Subtitles.srt(of: timeline, transcripts: [media.id: transcript])
    #expect(srt.hasPrefix("1\n00:00:00,500 --> 00:00:01,200\nHi all."))
  }

  @Test
  func `with nothing said there's nothing to export`() {
    #expect(throws: ExportError.nothingToExport(
      "there are no captions and nothing on the timeline is transcribed"
    )) {
      try Subtitles.srt(of: Timeline(), transcripts: [:])
    }
  }

}
