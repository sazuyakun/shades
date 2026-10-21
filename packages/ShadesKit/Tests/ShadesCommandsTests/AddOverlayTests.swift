import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct AddOverlayTests {

  // MARK: Internal

  @Test
  func `an overlay fills the frame above the footage, screened and silent`() throws {
    var project = try footage()
    try AddOverlay(mediaID: leak.id, at: seconds(2)).apply(to: &project)
    let overlay = try #require(project.timeline.allClips.first { $0.mediaID == leak.id })
    let track = try #require(project.timeline.tracks.first { $0.clips.contains(overlay) })
    #expect(project.timeline.label(of: track) == "V2")
    #expect(overlay.timelineStart == seconds(2))
    #expect(overlay.duration == seconds(4))
    #expect(overlay.blend == .screen)
    #expect(!overlay.isAudioEnabled)
    #expect(overlay.transform.scale > 1.3, "a 16:9 overlay is zoomed to fill the 4:3 frame")
  }

  @Test
  func `an overlay stops where the timeline ends, unless given a duration`() throws {
    var project = try footage()
    try AddOverlay(mediaID: leak.id, at: seconds(8), blend: .add, opacity: 0.5)
      .apply(to: &project)
    let overlay = try #require(project.timeline.allClips.first { $0.mediaID == leak.id })
    #expect(overlay.duration == seconds(2))
    #expect(overlay.blend == .add && overlay.opacity == 0.5)
    #expect(throws: CommandError.self) {
      try AddOverlay(mediaID: leak.id, at: .zero, duration: seconds(9)).apply(to: &project)
    }
  }

  @Test
  func `a sound can't be an overlay`() throws {
    var project = try footage()
    #expect(throws: CommandError.self) {
      try AddOverlay(mediaID: hum.id, at: .zero).apply(to: &project)
    }
  }

  // MARK: Private

  private let leak = makeMedia(seconds: 4, hasAudio: true)
  private let hum = makeMedia(seconds: 4, hasVideo: false)

  /// A 10-second video on V1, with the overlay and a sound imported.
  private func footage() throws -> Project {
    let video = makeMedia(seconds: 10)
    var project = Project(media: [video, leak, hum])
    try AppendClip(mediaID: video.id).apply(to: &project)
    return project
  }

}
