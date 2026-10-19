import Foundation
import ShadesCommands
import ShadesCore
@testable import ShadesPolish
import Testing

struct DuckingTests {

  // MARK: Internal

  @Test
  func `music dips before speech and comes back after it`() {
    let points = DuckingPlanner.envelope(
      speech: [range(4, 6)],
      from: .zero,
      to: seconds(10),
      duckTo: 0.25,
      attack: 0.5,
      release: 1,
    )
    #expect(points.map(\.time.seconds) == [0, 3.5, 4, 6, 7])
    #expect(points.map(\.gain) == [1, 1, 0.25, 0.25, 1])
  }

  @Test
  func `speech close together stays ducked between`() {
    let points = DuckingPlanner.envelope(
      speech: [range(2, 3), range(3.8, 5)],
      from: .zero,
      to: seconds(10),
      duckTo: 0.2,
      attack: 0.3,
      release: 0.6,
    )
    #expect(points.filter { $0.gain == 0.2 }.map(\.time.seconds) == [2, 5])
  }

  @Test
  func `ducking writes volume keyframes on the music clips only`() throws {
    let music = Media(
      url: URL(filePath: "/tmp/song.m4a"),
      duration: seconds(20),
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    var project = Project(media: [music])
    try AppendClip(mediaID: music.id).apply(to: &project)
    let track = try #require(project.timeline.tracks.firstIndex { $0.kind == .audio })
    try DuckMusic(track: track, speech: [range(5, 8)], duckTo: 0.3).apply(to: &project)
    let clip = try #require(project.timeline.tracks[track].clips.first)
    #expect(clip.keyframes.allSatisfy { $0.property == .volume })
    #expect(abs(clip.gain(at: seconds(6)) - 0.3) < 0.0001)
    #expect(clip.gain(at: seconds(15)) == 1)
  }

  // MARK: Private

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

  private func range(_ start: Double, _ end: Double) -> TimeRange {
    TimeRange(start: seconds(start), end: seconds(end))
  }

}
