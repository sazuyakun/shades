import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct TrackAndMarkerTests {
  @Test
  func `new video tracks go above the others`() throws {
    var project = Project()
    try AddTrack(kind: .video).apply(to: &project)
    #expect(project.timeline.tracks.map(\.kind) == [.video, .video, .audio])
  }

  @Test
  func `the last video track can't be removed`() throws {
    var project = Project()
    #expect(throws: CommandError.lastVideoTrack) {
      try RemoveTrack(track: "V1").apply(to: &project)
    }
    try RemoveTrack(track: "A1").apply(to: &project)
    #expect(project.timeline.tracks.count == 1)
  }

  @Test
  func `tracks can be muted and hidden`() throws {
    var project = Project()
    try SetTrack(track: "V1", muted: true).apply(to: &project)
    try SetTrack(track: "V1", hidden: true).apply(to: &project)
    #expect(project.timeline.tracks[0].isMuted)
    #expect(project.timeline.tracks[0].isHidden)
  }

  @Test
  func `closing gaps packs every track`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try OverwriteClip(mediaID: media.id, at: seconds(3)).apply(to: &project)
    try CloseGaps().apply(to: &project)
    #expect(project.timeline.allClips.first?.timelineStart == seconds(0))
  }

  @Test
  func `markers stay in time order and can be removed`() throws {
    var project = Project()
    try AddMarker(at: seconds(5), name: "end").apply(to: &project)
    try AddMarker(at: seconds(1), name: "start").apply(to: &project)
    #expect(project.timeline.markers.map(\.name) == ["start", "end"])
    let id = try #require(project.timeline.markers.first?.id)
    try RemoveMarker(markerID: id).apply(to: &project)
    #expect(project.timeline.markers.map(\.name) == ["end"])
  }

  @Test
  func `removing media removes its clips`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    try RemoveMedia(mediaID: media.id).apply(to: &project)
    #expect(project.media.isEmpty)
    #expect(project.timeline.allClips.isEmpty)
  }
}
