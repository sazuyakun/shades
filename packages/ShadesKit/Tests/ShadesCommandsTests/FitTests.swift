import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct FitTests {

  // MARK: Internal

  @Test
  func `on a filling timeline 16:9 footage fills the 4:3 frame as it's placed`() throws {
    var project = filling([wide, picture, sound])
    try AppendClip(mediaID: wide.id).apply(to: &project)
    try PlaceOnTop(mediaID: wide.id, at: seconds(0)).apply(to: &project)
    try InsertClip(mediaID: wide.id, at: seconds(0)).apply(to: &project)
    try OverwriteClip(mediaID: wide.id, at: seconds(1)).apply(to: &project)
    let videoScales = project.timeline.allClips.filter { $0.mediaID == wide.id }
      .map(\.transform.scale)
    #expect(videoScales.count == 4)
    #expect(videoScales.allSatisfy { abs($0 - 4.0 / 3) < 0.001 })
  }

  @Test
  func `pictures and sound aren't filled`() throws {
    var project = filling([wide, picture, sound])
    try AppendClip(mediaID: picture.id).apply(to: &project)
    try AppendClip(mediaID: sound.id).apply(to: &project)
    #expect(project.timeline.allClips.allSatisfy { $0.transform.scale == 1 })
  }

  @Test
  func `a fitting timeline places footage inside the frame`() throws {
    var project = Project(media: [wide])
    try AppendClip(mediaID: wide.id).apply(to: &project)
    #expect(project.timeline.allClips.first?.transform.scale == 1)
  }

  @Test
  func `set_clip fit switches one clip between filling and fitting`() throws {
    var project = Project(media: [wide])
    try AppendClip(mediaID: wide.id).apply(to: &project)
    let clipID = try #require(project.timeline.allClips.first?.id)
    try SetClip(clipID: clipID, fit: .fill).apply(to: &project)
    #expect(abs((project.timeline.allClips.first?.transform.scale ?? 0) - 4.0 / 3) < 0.001)
    try SetClip(clipID: clipID, fit: .fit).apply(to: &project)
    #expect(project.timeline.allClips.first?.transform.scale == 1)
  }

  @Test
  func `fit and scale together are refused`() throws {
    var project = Project(media: [wide])
    try AppendClip(mediaID: wide.id).apply(to: &project)
    let clipID = try #require(project.timeline.allClips.first?.id)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: clipID, scale: 2, fit: .fill).apply(to: &project)
    }
  }

  @Test
  func `the default fit can be changed for clips placed after`() throws {
    var project = Project(media: [wide])
    try SetDefaultFit(fit: .fill).apply(to: &project)
    #expect(project.timeline.defaultFit == .fill)
    try AppendClip(mediaID: wide.id).apply(to: &project)
    #expect(abs((project.timeline.allClips.first?.transform.scale ?? 0) - 4.0 / 3) < 0.001)
  }

  // MARK: Private

  private let wide = Media(
    url: URL(filePath: "/tmp/wide.mov"),
    duration: MediaTime(seconds: 4),
    width: 1920,
    height: 1080,
    hasAudio: true,
  )
  private let picture = Media(
    url: URL(filePath: "/tmp/sticker.png"),
    duration: MediaTime(seconds: 4),
    width: 1920,
    height: 1080,
    hasAudio: false,
    isStill: true,
  )
  private let sound = makeMedia(seconds: 4, hasVideo: false)

  /// A project of `media` on a timeline that fills the frame with new footage.
  private func filling(_ media: [Media]) -> Project {
    var project = Project(media: media)
    project.timeline.defaultFit = .fill
    return project
  }

}
