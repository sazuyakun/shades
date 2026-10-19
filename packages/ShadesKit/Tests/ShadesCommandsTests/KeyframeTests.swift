import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct KeyframeTests {

  // MARK: Internal

  @Test
  func `keyframes are set at timeline times and stored in source time`() throws {
    var project = try clipAtTwoSeconds()
    let clip = try #require(project.timeline.allClips.first)
    try SetKeyframes(clipID: clip.id, keyframes: [
      SetKeyframes.Key(property: .scale, at: seconds(3), value: 2, easing: .spring),
      SetKeyframes.Key(property: .scale, at: seconds(2), value: 1, easing: nil),
    ]).apply(to: &project)
    let keyframes = try #require(project.timeline.allClips.first?.keyframes)
    #expect(keyframes.map(\.time) == [seconds(0), seconds(1)])
    #expect(keyframes.map(\.easing) == [.linear, .spring])
  }

  @Test
  func `a keyframe at the same moment replaces the old one`() throws {
    var project = try clipAtTwoSeconds()
    let clip = try #require(project.timeline.allClips.first)
    for value in [0.2, 0.7] {
      try SetKeyframes(clipID: clip.id, keyframes: [
        SetKeyframes.Key(property: .opacity, at: seconds(2.5), value: value, easing: nil)
      ]).apply(to: &project)
    }
    let keyframes = try #require(project.timeline.allClips.first?.keyframes)
    #expect(keyframes.map(\.value) == [0.7])
  }

  @Test
  func `keyframes outside the clip or out of range are refused`() throws {
    var project = try clipAtTwoSeconds()
    let clip = try #require(project.timeline.allClips.first)
    #expect(throws: CommandError.self) {
      try SetKeyframes(clipID: clip.id, keyframes: [
        SetKeyframes.Key(property: .x, at: seconds(1), value: 0, easing: nil)
      ]).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetKeyframes(clipID: clip.id, keyframes: [
        SetKeyframes.Key(property: .opacity, at: seconds(3), value: 2, easing: nil)
      ]).apply(to: &project)
    }
  }

  @Test
  func `splitting an animated clip keeps the motion on both halves`() throws {
    var project = try clipAtTwoSeconds()
    let clip = try #require(project.timeline.allClips.first)
    try SetKeyframes(clipID: clip.id, keyframes: [
      SetKeyframes.Key(property: .x, at: seconds(2), value: 0, easing: nil),
      SetKeyframes.Key(property: .x, at: seconds(4), value: 1, easing: nil),
    ]).apply(to: &project)
    let before = try #require(project.timeline.allClips.first).value(of: .x, at: seconds(3.5))
    try SplitClip(clipID: clip.id, at: seconds(3)).apply(to: &project)
    let second = try #require(project.timeline.allClips.last)
    #expect(abs(second.value(of: .x, at: seconds(3.5)) - before) < 0.0001)
  }

  @Test
  func `keyframes are removed by property, by moment or all at once`() throws {
    var project = try clipAtTwoSeconds()
    let clip = try #require(project.timeline.allClips.first)
    try SetKeyframes(clipID: clip.id, keyframes: [
      SetKeyframes.Key(property: .x, at: seconds(2), value: 0, easing: nil),
      SetKeyframes.Key(property: .x, at: seconds(3), value: 1, easing: nil),
      SetKeyframes.Key(property: .y, at: seconds(3), value: 1, easing: nil),
    ]).apply(to: &project)
    try RemoveKeyframes(clipID: clip.id, property: .x, at: seconds(3)).apply(to: &project)
    #expect(project.timeline.allClips.first?.keyframes.count == 2)
    try RemoveKeyframes(clipID: clip.id, property: .y).apply(to: &project)
    #expect(project.timeline.allClips.first?.keyframes.count == 1)
    try RemoveKeyframes(clipID: clip.id).apply(to: &project)
    #expect(project.timeline.allClips.first?.keyframes.isEmpty == true)
    #expect(throws: CommandError.self) {
      try RemoveKeyframes(clipID: clip.id).apply(to: &project)
    }
  }

  // MARK: Private

  /// A 3-second clip placed at 2 s.
  private func clipAtTwoSeconds() throws -> Project {
    let media = makeMedia(seconds: 3)
    var project = Project(media: [media])
    try InsertClip(mediaID: media.id, at: seconds(2)).apply(to: &project)
    return project
  }

}
