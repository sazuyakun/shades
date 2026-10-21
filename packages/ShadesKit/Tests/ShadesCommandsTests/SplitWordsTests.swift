import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct SplitWordsTests {

  // MARK: Internal

  @Test
  func `splitting text makes one clip per word, each on its own track with the same look`() throws {
    var project = Project()
    let style = TextStyle(size: 0.1, anchor: .center)
    try AddText(
      text: "big bold words",
      at: seconds(1),
      duration: seconds(2),
      style: style,
      reveal: .pop,
      words: timings,
    ).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    try SplitWords(clipID: clip.id).apply(to: &project)
    let words = project.timeline.tracks.filter { $0.kind == .text }.flatMap(\.clips)
    #expect(words.map { $0.text?.shownText } == ["big", "bold", "words"])
    #expect(words.map { $0.text?.word } == [0, 1, 2])
    #expect(words.first?.id == clip.id, "the first word keeps the clip")
    #expect(words.allSatisfy { $0.timelineStart == seconds(1) && $0.duration == seconds(2) })
    #expect(words.allSatisfy { $0.text?.style == style && $0.text?.reveal == .pop })
    #expect(words.allSatisfy { $0.text?.words == timings })
    #expect(project.timeline.tracks.count { $0.kind == .text } == 3)
  }

  @Test
  func `each word can then move on its own`() throws {
    var project = Project()
    try AddText(text: "one two", at: .zero, duration: seconds(2)).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    try SplitWords(clipID: clip.id).apply(to: &project)
    let second = try #require(project.timeline.allClips.first { $0.text?.word == 1 })
    try SetClip(clipID: second.id, y: -0.2, rotation: 15).apply(to: &project)
    let first = try #require(project.timeline.clip(withID: clip.id))
    #expect(first.transform == .identity)
    #expect(project.timeline.clip(withID: second.id)?.transform.rotation == 15)
  }

  @Test
  func `only whole text of more than one word splits`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try AddText(text: "alone", at: .zero, duration: seconds(1)).apply(to: &project)
    try AddText(text: "two words", at: seconds(1), duration: seconds(1)).apply(to: &project)
    let clips = project.timeline.allClips
    for clip in clips.filter({ $0.text?.text != "two words" }) {
      #expect(throws: CommandError.self) { try SplitWords(clipID: clip.id).apply(to: &project) }
    }
    let text = try #require(clips.first { $0.text?.text == "two words" })
    try SplitWords(clipID: text.id).apply(to: &project)
    #expect(throws: CommandError.self) { try SplitWords(clipID: text.id).apply(to: &project) }
  }

  @Test
  func `add_text takes word timings from Claude and refuses the wrong number`() throws {
    let command = try CommandRegistry.command(named: "add_text", arguments: [
      "text": "big bold words",
      "at": .number(0),
      "duration": .number(2),
      "words": .array(timings.map { word in
        [
          "text": .string(word.text),
          "start": .number(word.start.seconds),
          "end": .number(word.end.seconds),
        ]
      }),
    ])
    var project = Project()
    try command.apply(to: &project)
    #expect(project.timeline.allClips.first?.text?.words == timings)
    #expect(throws: CommandError.self) {
      try AddText(text: "two words", at: .zero, duration: seconds(1), words: timings)
        .apply(to: &project)
    }
  }

  // MARK: Private

  private let timings = [
    TimedWord(text: "big", start: .zero, end: seconds(0.4)),
    TimedWord(text: "bold", start: seconds(0.4), end: seconds(0.9)),
    TimedWord(text: "words", start: seconds(0.9), end: seconds(1.5)),
  ]

}
