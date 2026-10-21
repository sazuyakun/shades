import Foundation
import ShadesCommands
import ShadesCore
import Testing

struct BendTests {
  @Test
  func `a layer bends and its bend can be animated`() throws {
    let media = makeMedia(seconds: 2)
    var project = Project(media: [media])
    try AppendClip(mediaID: media.id).apply(to: &project)
    let clip = try #require(project.timeline.allClips.first)
    try SetClip(clipID: clip.id, bend: 90).apply(to: &project)
    #expect(project.timeline.clip(withID: clip.id)?.transform.bend == 90)
    #expect(throws: CommandError.self) {
      try SetClip(clipID: clip.id, bend: 400).apply(to: &project)
    }
    try SetKeyframes(clipID: clip.id, keyframes: [
      SetKeyframes.Key(property: .bend, at: .zero, value: 0, easing: nil),
      SetKeyframes.Key(property: .bend, at: seconds(2), value: -60, easing: nil),
    ]).apply(to: &project)
    let bending = try #require(project.timeline.clip(withID: clip.id))
    #expect(bending.transform(at: seconds(1)).bend == -30)
  }

  @Test
  func `transforms saved before bends existed load flat`() throws {
    let json = Data(#"{"x": 0.1, "tiltY": 20}"#.utf8)
    let transform = try JSONDecoder().decode(ClipTransform.self, from: json)
    #expect(transform.bend == 0 && transform.tiltY == 20)
  }
}
