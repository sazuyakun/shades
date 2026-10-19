import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct ApplyMotionTests {

  // MARK: Internal

  @Test
  func `pop springs a layer in from nothing to where it rests`() throws {
    var (project, ids) = try stickers(1)
    try SetClip(clipID: ids[0], scale: 0.4).apply(to: &project)
    try ApplyMotion(clipIDs: ids, preset: .pop).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: ids[0]))
    #expect(clip.value(of: .scale, at: seconds(0)) < 0.05)
    #expect(clip.value(of: .opacity, at: seconds(0)) == 0)
    #expect(abs(clip.value(of: .scale, at: seconds(1)) - 0.4) < 0.0001)
  }

  @Test
  func `slide in starts off the chosen edge`() throws {
    var (project, ids) = try stickers(1)
    try ApplyMotion(clipIDs: ids, preset: .slideIn, edge: .right).apply(to: &project)
    let clip = try #require(project.timeline.clip(withID: ids[0]))
    #expect(clip.value(of: .x, at: seconds(0)) > 1)
    #expect(clip.value(of: .x, at: seconds(1)) == 0)
  }

  @Test
  func `orbiting clips share a ring, spread evenly, and move round it`() throws {
    var (project, ids) = try stickers(4)
    try ApplyMotion(clipIDs: ids, preset: .orbit, radius: 0.3).apply(to: &project)
    let clips = try ids.map { try #require(project.timeline.clip(withID: $0)) }
    let aspect = project.timeline.format.aspect
    for clip in clips {
      let x = clip.value(of: .x, at: seconds(2)) * aspect
      let y = clip.value(of: .y, at: seconds(2))
      #expect(abs((x * x + y * y).squareRoot() - 0.3) < 0.02)
    }
    #expect(abs(clips[0].value(of: .y, at: seconds(0)) - -0.3) < 0.001)
    #expect(abs(clips[2].value(of: .y, at: seconds(0)) - 0.3) < 0.001)
    #expect(clips[0].value(of: .x, at: seconds(1)) != clips[0].value(of: .x, at: seconds(0)))
  }

  @Test
  func `stacked clips land one after another and scattered ones fade away`() throws {
    var (project, ids) = try stickers(3)
    try ApplyMotion(clipIDs: ids, preset: .stack, duration: seconds(0.5)).apply(to: &project)
    let landed = try ids.map { id in
      try #require(project.timeline.clip(withID: id)).value(of: .opacity, at: seconds(0.4))
    }
    #expect(landed[0] == 1)
    #expect(landed[2] == 0)
    try ApplyMotion(clipIDs: ids, preset: .scatter, at: seconds(3)).apply(to: &project)
    let gone = try #require(project.timeline.clip(withID: ids[1]))
    #expect(gone.value(of: .opacity, at: seconds(4)) == 0)
  }

  // MARK: Private

  /// `count` still clips stacked on their own tracks, each 5 seconds from 0.
  private func stickers(_ count: Int) throws -> (Project, [Clip.ID]) {
    let still = Media(
      url: URL(filePath: "/tmp/sticker.png"),
      duration: Media.stillLength,
      width: 400,
      height: 400,
      hasAudio: false,
      isStill: true,
    )
    var project = Project(media: [still])
    for _ in 0 ..< count {
      try PlaceOnTop(mediaID: still.id, at: .zero).apply(to: &project)
    }
    return (project, project.timeline.allClips.map(\.id))
  }

}
