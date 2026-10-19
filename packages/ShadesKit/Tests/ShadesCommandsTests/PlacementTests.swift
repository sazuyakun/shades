import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct PlacementTests {

  // MARK: Internal

  @Test
  func `appending places clips back to back`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    try AppendClip(mediaID: video.id).apply(to: &project)
    #expect(project.timeline.tracks[0].clips.map(\.timelineStart) == [seconds(0), seconds(4)])
  }

  @Test
  func `a source range places just that part`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id, sourceStart: seconds(1), sourceEnd: seconds(2.5))
      .apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(clip.sourceStart == seconds(1))
    #expect(clip.duration == seconds(1.5))
  }

  @Test
  func `a source range past the media's end is rejected`() {
    var project = Project(media: [video])
    #expect(throws: CommandError.self) {
      try AppendClip(mediaID: video.id, sourceEnd: seconds(9)).apply(to: &project)
    }
  }

  @Test
  func `sound-only media goes on the first audio track`() throws {
    var project = Project(media: [music])
    try AppendClip(mediaID: music.id).apply(to: &project)
    #expect(project.timeline.tracks[1].clips.count == 1)
  }

  @Test
  func `video can't go on an audio track`() {
    var project = Project(media: [video])
    #expect(throws: CommandError.wrongTrackKind(track: "A1", needs: .video)) {
      try AppendClip(mediaID: video.id, track: "A1").apply(to: &project)
    }
  }

  @Test
  func `inserting pushes later clips on that track only`() throws {
    var project = Project(media: [video, music])
    try AppendClip(mediaID: video.id).apply(to: &project)
    try AppendClip(mediaID: music.id).apply(to: &project)
    try InsertClip(mediaID: video.id, at: seconds(1), sourceEnd: seconds(2)).apply(to: &project)
    let v1 = project.timeline.tracks[0].clips
    #expect(v1.map(\.timelineStart) == [seconds(0), seconds(1), seconds(3)])
    #expect(project.timeline.tracks[1].clips[0].timelineStart == seconds(0))
  }

  @Test
  func `overwriting replaces what was there and moves nothing`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    try OverwriteClip(mediaID: video.id, at: seconds(1), sourceEnd: seconds(2))
      .apply(to: &project)
    let clips = project.timeline.tracks[0].clips
    #expect(clips.map(\.timelineStart) == [seconds(0), seconds(1), seconds(3)])
    #expect(project.timeline.duration == seconds(4))
  }

  @Test
  func `placing on top uses a free upper track or adds one`() throws {
    var project = Project(media: [video])
    try AppendClip(mediaID: video.id).apply(to: &project)
    try PlaceOnTop(mediaID: video.id, at: seconds(1), sourceEnd: seconds(1)).apply(to: &project)
    try PlaceOnTop(mediaID: video.id, at: seconds(1.5), sourceEnd: seconds(1)).apply(to: &project)
    try PlaceOnTop(mediaID: video.id, at: seconds(3), sourceEnd: seconds(1)).apply(to: &project)
    let labels = project.timeline.tracks.map(project.timeline.label(of:))
    #expect(labels == ["V1", "V2", "V3", "A1"])
    #expect(project.timeline.tracks[1].clips.count == 2)
    #expect(project.timeline.tracks[2].clips.count == 1)
  }

  @Test
  func `times snap to the timeline's frames`() throws {
    var project = Project(media: [video])
    try InsertClip(mediaID: video.id, at: seconds(1.01), sourceEnd: seconds(1)).apply(to: &project)
    #expect(project.timeline.allClips.first?.timelineStart == seconds(1))
  }

  @Test
  func `a still is placed for five seconds and can be trimmed to any length`() throws {
    let still = Media(
      url: URL(filePath: "/tmp/sticker.png"),
      duration: Media.stillLength,
      width: 400,
      height: 300,
      hasAudio: false,
      isStill: true,
    )
    var project = Project(media: [still])
    try AppendClip(mediaID: still.id).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    #expect(clip.duration == seconds(5))
    try TrimClip(clipID: clip.id, end: seconds(30)).apply(to: &project)
    #expect(project.timeline.allClips.first?.duration == seconds(30))
  }

  // MARK: Private

  private let video = makeMedia(seconds: 4)
  private let music = makeMedia(seconds: 10, hasVideo: false)

}
