import Foundation
import ShadesCore
import Testing

struct SpeedTests {

  // MARK: Internal

  @Test
  func `a clip at twice the speed gets through its source twice as fast`() {
    let clip = makeClip(speed: 2)
    #expect(clip.sourceTime(at: seconds(11)) == seconds(7))
    #expect(clip.timelineTime(atSource: seconds(7)) == seconds(11))
    #expect(clip.sourceEnd == seconds(13))
  }

  @Test
  func `a freeze frame shows its first frame the whole time`() {
    let clip = makeClip(speed: 0)
    #expect(clip.isFrozen)
    #expect(clip.sourceTime(at: seconds(12)) == seconds(5))
    #expect(clip.sourceEnd == seconds(5))
    #expect(clip.gain(at: seconds(12)) == 0)
  }

  @Test
  func `a ramp's source time is its speed summed over the timeline`() {
    // why: from 1× at source 5 s to 3× at 7 s the speed is 1 + (s − 5), so playing that stretch
    // takes ∫ ds / (1 + s − 5) = ln 3 seconds.
    let clip = makeClip(keyframes: [
      Keyframe(property: .speed, time: seconds(5), value: 1),
      Keyframe(property: .speed, time: seconds(7), value: 3),
    ])
    let rampEnd = clip.timelineTime(atSource: seconds(7)).seconds
    #expect(abs(rampEnd - (10 + log(3))) < 0.002)
    #expect(abs(clip.sourceTime(at: seconds(12)).seconds - (7 + 3 * (2 - log(3)))) < 0.005)
  }

  @Test(arguments: Easing.allCases)
  func `source and timeline times undo each other along a ramp`(easing: Easing) {
    let clip = makeClip(keyframes: [
      Keyframe(property: .speed, time: seconds(5.5), value: 0.2, easing: easing),
      Keyframe(property: .speed, time: seconds(6.5), value: 8, easing: easing),
      Keyframe(property: .speed, time: seconds(9), value: 0.5),
    ])
    var previous = clip.sourceTime(at: seconds(10))
    for step in 1 ... 120 {
      let time = seconds(10 + Double(step) / 24)
      let source = clip.sourceTime(at: time)
      #expect(source > previous, "the picture never runs backwards or stalls")
      // why: source times land on 1/600 s, which at the slowest speed (0.1×) spans 1/60 s of
      // timeline, so a round trip can be off by half of that.
      #expect(abs((clip.timelineTime(atSource: source) - time).seconds) <= 1.0 / 120)
      previous = source
    }
  }

  @Test
  func `splitting a ramped clip keeps every frame where it was`() throws {
    let clip = makeClip(keyframes: [
      Keyframe(property: .speed, time: seconds(5), value: 0.5, easing: .easeInOut),
      Keyframe(property: .speed, time: seconds(7), value: 4),
    ])
    var track = Track(kind: .video, clips: [clip])
    try #require(track.split(at: seconds(12)) != nil)
    let left = track.clips[0]
    let right = track.clips[1]
    #expect(left.sourceEnd == right.sourceStart)
    for time in [seconds(12.5), seconds(13), seconds(14.5)] {
      #expect(abs((right.sourceTime(at: time) - clip.sourceTime(at: time)).seconds) < 0.002)
    }
  }

  @Test
  func `sound plays stretched at moderate speeds and is muted at extreme ones`() {
    #expect(makeClip(speed: 2).gain(at: seconds(11)) == 1)
    #expect(makeClip(speed: 0.5).gain(at: seconds(11)) == 1)
    #expect(makeClip(speed: 8).gain(at: seconds(11)) == 0)
    #expect(makeClip(speed: 0.1).gain(at: seconds(11)) == 0)
  }

  @Test
  func `spoken words stretch with the clip's speed`() {
    let clip = makeClip(speed: 2)
    let mediaID = clip.mediaID ?? UUID()
    let timeline = Timeline(tracks: [Track(kind: .video, clips: [clip])])
    let words = [
      TranscriptWord(text: "fast", start: seconds(7), end: seconds(8)),
      TranscriptWord(text: "gone", start: seconds(14), end: seconds(15)),
    ]
    let transcript = Transcript(
      segments: [TranscriptSegment(text: "", start: seconds(7), end: seconds(15), words: words)],
      language: nil,
    )
    let heard = timeline.spokenWords(transcripts: [mediaID: transcript])
    #expect(heard.map(\.text) == ["fast"])
    #expect(heard.first?.start == seconds(11))
    #expect(heard.first?.end == seconds(11.5))
  }

  @Test
  func `a clip's speed is saved, and clips saved before speed play at normal speed`() throws {
    let clip = makeClip(speed: 0.5)
    let data = try JSONEncoder().encode(clip)
    #expect(try JSONDecoder().decode(Clip.self, from: data).speed == 0.5)
    var fields = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    fields["speed"] = nil
    let old = try JSONSerialization.data(withJSONObject: fields)
    #expect(try JSONDecoder().decode(Clip.self, from: old).speed == 1)
  }

  // MARK: Private

  /// A 4-second clip at 10 s on the timeline, showing its media from 5 s.
  private func makeClip(speed: Double = 1, keyframes: [Keyframe] = []) -> Clip {
    Clip(
      mediaID: UUID(),
      sourceStart: seconds(5),
      duration: seconds(4),
      timelineStart: seconds(10),
      keyframes: keyframes,
      speed: speed,
    )
  }

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

}
