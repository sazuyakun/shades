import Foundation
import ShadesCore
import Testing

struct AnimationTests {

  // MARK: Internal

  @Test(arguments: Easing.allCases)
  func `every easing starts at 0 and arrives at 1`(easing: Easing) {
    #expect(easing.progress(0) == 0)
    #expect(easing.progress(1) == 1)
  }

  @Test
  func `easings shape the move between keyframes`() {
    #expect(Easing.linear.progress(0.5) == 0.5)
    #expect(Easing.easeIn.progress(0.5) < 0.5)
    #expect(Easing.easeOut.progress(0.5) > 0.5)
    #expect(abs(Easing.easeInOut.progress(0.5) - 0.5) < 0.0001)
    #expect(Easing.hold.progress(0.99) == 0)
  }

  @Test
  func `springs overshoot and settle by the next keyframe`() {
    let spring = stride(from: 0.0, through: 1, by: 0.01).map(Easing.spring.progress)
    let bouncy = stride(from: 0.0, through: 1, by: 0.01).map(Easing.bouncy.progress)
    #expect((spring.max() ?? 0) > 1)
    #expect((bouncy.max() ?? 0) > (spring.max() ?? 0))
    #expect(abs(Easing.spring.progress(0.99) - 1) < 0.01)
    #expect(abs(Easing.bouncy.progress(0.99) - 1) < 0.01)
  }

  @Test
  func `without keyframes a clip keeps its fixed values`() {
    let clip = makeClip(keyframes: [])
    #expect(clip.transform(at: time(1)) == clip.transform)
    #expect(clip.opacity(at: time(1)) == 0.8)
  }

  @Test
  func `keyframes move a property, holding it before the first and after the last`() {
    let clip = makeClip(keyframes: [
      Keyframe(property: .x, time: time(1), value: 0),
      Keyframe(property: .x, time: time(3), value: 1),
    ])
    #expect(clip.value(of: .x, at: time(10)) == 0)
    #expect(clip.value(of: .x, at: time(11)) == 0)
    #expect(abs(clip.value(of: .x, at: time(12)) - 0.5) < 0.0001)
    #expect(clip.value(of: .x, at: time(14)) == 1)
    #expect(clip.value(of: .y, at: time(12)) == 0.1)
  }

  @Test
  func `keyframes stay on the picture when the clip starts later in its source`() {
    var clip = makeClip(keyframes: [
      Keyframe(property: .opacity, time: time(2), value: 0),
      Keyframe(property: .opacity, time: time(4), value: 1),
    ])
    let before = clip.opacity(at: time(13))
    clip.sourceStart = time(1)
    clip.timelineStart = time(11)
    #expect(clip.opacity(at: time(13)) == before)
  }

  // MARK: Private

  /// A clip placed at 10 s on the timeline, showing its source from 0 s.
  private func makeClip(keyframes: [Keyframe]) -> Clip {
    Clip(
      source: .text(TextContent(text: "hi")),
      sourceStart: .zero,
      duration: time(5),
      timelineStart: time(10),
      transform: ClipTransform(x: 0.2, y: 0.1, scale: 1, rotation: 0),
      opacity: 0.8,
      keyframes: keyframes,
    )
  }

  private func time(_ seconds: Double) -> MediaTime {
    MediaTime(seconds: seconds)
  }

}
