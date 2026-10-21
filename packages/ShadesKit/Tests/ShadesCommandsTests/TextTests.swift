import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct TextTests {
  @Test
  func `text goes on a new text track, labeled T1`() throws {
    var project = Project()
    try AddText(text: "Chul ka keeda", at: seconds(1), duration: seconds(2)).apply(to: &project)
    let track = try #require(project.timeline.tracks.first { $0.kind == .text })
    #expect(project.timeline.label(of: track) == "T1")
    #expect(track.clips.first?.text?.text == "Chul ka keeda")
    #expect(track.clips.first?.timelineEnd == seconds(3))
  }

  @Test
  func `new text on a named track replaces text already there`() throws {
    var project = Project()
    try AddText(text: "one", at: seconds(0), duration: seconds(2)).apply(to: &project)
    try AddText(text: "two", at: seconds(1), duration: seconds(2), track: "T1").apply(to: &project)
    let clips = try #require(project.timeline.tracks.first { $0.kind == .text }?.clips)
    #expect(clips.map { $0.text?.text } == ["one", "two"])
    #expect(clips[0].duration == seconds(1))
  }

  @Test
  func `new text without a track goes where it covers nothing, like over captions`() throws {
    var project = Project()
    try AddText(text: "caption", at: seconds(0), duration: seconds(2)).apply(to: &project)
    try AddText(text: "next caption", at: seconds(2), duration: seconds(1)).apply(to: &project)
    try AddText(text: "TITLE", at: seconds(1), duration: seconds(2)).apply(to: &project)
    let tracks = project.timeline.tracks.filter { $0.kind == .text }
    #expect(tracks.map { $0.clips.map { $0.text?.text } } == [
      ["caption", "next caption"],
      ["TITLE"],
    ])
  }

  @Test
  func `text can be changed, trimmed to any length and split`() throws {
    var project = Project()
    try AddText(text: "hello", at: seconds(0), duration: seconds(2)).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    try SetText(clipID: clip.id, text: "hi").apply(to: &project)
    try TrimClip(clipID: clip.id, end: seconds(10)).apply(to: &project)
    try SplitClip(clipID: clip.id, at: seconds(5)).apply(to: &project)
    let texts = project.timeline.allClips.map { $0.text?.text }
    #expect(texts == ["hi", "hi"])
    #expect(project.timeline.duration == seconds(10))
  }

  @Test
  func `media clips aren't text and empty text is refused`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(throws: CommandError.self) {
      try SetText(clipID: clip.id, text: "x").apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try AddText(text: "  ", at: seconds(0), duration: seconds(1)).apply(to: &project)
    }
  }
}
