import Foundation
import ShadesCore
import Testing

struct ClipGainTests {
  @Test
  func `fades rise from and fall to silence at a clip's ends`() {
    let clip = Clip(
      mediaID: UUID(),
      sourceStart: .zero,
      duration: MediaTime(seconds: 10),
      timelineStart: MediaTime(seconds: 10),
      volume: 0.8,
      fadeIn: MediaTime(seconds: 2),
      fadeOut: MediaTime(seconds: 4),
    )
    #expect(clip.gain(at: MediaTime(seconds: 10)) == 0)
    #expect(abs(clip.gain(at: MediaTime(seconds: 11)) - 0.4) < 0.0001)
    #expect(clip.gain(at: MediaTime(seconds: 14)) == 0.8)
    #expect(abs(clip.gain(at: MediaTime(seconds: 18)) - 0.4) < 0.0001)
  }

  @Test
  func `volume keyframes shape the level`() {
    let clip = Clip(
      mediaID: UUID(),
      sourceStart: .zero,
      duration: MediaTime(seconds: 4),
      timelineStart: .zero,
      keyframes: [
        Keyframe(property: .volume, time: .zero, value: 1),
        Keyframe(property: .volume, time: MediaTime(seconds: 2), value: 0),
      ],
    )
    #expect(abs(clip.gain(at: MediaTime(seconds: 1)) - 0.5) < 0.0001)
    #expect(clip.gain(at: MediaTime(seconds: 3)) == 0)
  }
}
