import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct AddStickerTests {

  // MARK: Internal

  @Test
  func `a sticker lands above the video, die-cut, popping in, with its sound`() throws {
    var project = try footage()
    try AddSticker(mediaID: picture.id, at: seconds(1), soundID: pop.id).apply(to: &project)
    let tracks = project.timeline.tracks
    let sticker = try #require(tracks.filter { $0.kind == .video }.last?.clips.first)
    #expect(project.timeline.label(of: try #require(tracks.first { $0.clips.contains(sticker) }))
      == "V2")
    #expect(sticker.timelineStart == seconds(1))
    #expect(sticker.duration == seconds(3))
    #expect(sticker.sticker == StickerLook())
    #expect(sticker.transform.scale == 0.35)
    #expect(sticker.value(of: .scale, at: seconds(1)) < 0.05)
    let sound = try #require(tracks.filter { $0.kind == .audio }.last?.clips.first)
    #expect(sound.mediaID == pop.id)
    #expect(sound.timelineStart == seconds(1))
  }

  @Test
  func `a sound can't be a sticker`() throws {
    var project = try footage()
    #expect(throws: CommandError.self) {
      try AddSticker(mediaID: pop.id, at: .zero).apply(to: &project)
    }
  }

  @Test
  func `the sticker look comes off with no border and no shadow`() throws {
    var project = try footage()
    try AddSticker(mediaID: picture.id, at: .zero).apply(to: &project)
    let id = try #require(project.timeline.allClips.first { $0.mediaID == picture.id }?.id)
    try SetClip(clipID: id, sticker: StickerLook(border: 0, shadow: false)).apply(to: &project)
    #expect(project.timeline.clip(withID: id)?.sticker == nil)
  }

  // MARK: Private

  private let picture = Media(
    url: URL(filePath: "/tmp/camera.png"),
    duration: Media.stillLength,
    width: 400,
    height: 400,
    hasAudio: false,
    isStill: true,
  )
  private let pop = makeMedia(seconds: 0.5, hasVideo: false)

  /// A 10-second video on V1, with the picture and the pop sound imported.
  private func footage() throws -> Project {
    let video = makeMedia(seconds: 10)
    var project = Project(media: [video, picture, pop])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
