import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct CameraTests {

  // MARK: Internal

  @Test
  func `the camera zooms between keyframes at timeline times`() throws {
    var project = Project()
    try SetCamera(keyframes: [key(.scale, at: 1, value: 1), key(.scale, at: 3, value: 2)])
      .apply(to: &project)
    project.timeline.camera = project.timeline.camera.map { keyframe in
      var linear = keyframe
      linear.easing = .linear
      return linear
    }
    #expect(project.timeline.camera(at: seconds(0)).scale == 1)
    #expect(abs(project.timeline.camera(at: seconds(2)).scale - 1.5) < 0.0001)
    #expect(project.timeline.camera(at: seconds(5)).scale == 2)
  }

  @Test
  func `camera moves ease in and out unless told otherwise`() throws {
    var project = Project()
    try SetCamera(keyframes: [key(.scale, at: 0, value: 1)]).apply(to: &project)
    #expect(project.timeline.camera.first?.easing == .easeInOut)
  }

  @Test
  func `clearing the camera replaces its moves`() throws {
    var project = Project()
    try SetCamera(keyframes: [key(.x, at: 0, value: 0.2)]).apply(to: &project)
    try SetCamera(keyframes: [key(.tiltX, at: 1, value: 10)], clear: true).apply(to: &project)
    #expect(project.timeline.camera.map(\.property) == [.tiltX])
  }

  @Test
  func `the camera has no opacity and zoom stays sensible`() {
    var project = Project()
    #expect(throws: CommandError.self) {
      try SetCamera(keyframes: [key(.opacity, at: 0, value: 0.5)]).apply(to: &project)
    }
    #expect(throws: CommandError.self) {
      try SetCamera(keyframes: [key(.scale, at: 0, value: 0)]).apply(to: &project)
    }
  }

  @Test
  func `layers tilt and move in depth within limits`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    try SetClip(clipID: clip.id, tiltX: 20, tiltY: -30, depth: -1).apply(to: &project)
    let transform = try #require(project.timeline.allClips.first?.transform)
    #expect(transform == ClipTransform(tiltX: 20, tiltY: -30, depth: -1))
    #expect(throws: CommandError.self) {
      try SetClip(clipID: clip.id, tiltX: 10, tiltY: 120).apply(to: &project)
    }
  }

  @Test
  func `a track can be told to follow the camera or not`() throws {
    var project = Project()
    try SetTrack(track: "V1", followsCamera: false).apply(to: &project)
    #expect(project.timeline.tracks[0].followsCamera == false)
  }

  // MARK: Private

  private func key(_ property: AnimatedProperty, at time: Double, value: Double) -> SetKeyframes
    .Key
  {
    SetKeyframes.Key(property: property, at: seconds(time), value: value, easing: nil)
  }

}
