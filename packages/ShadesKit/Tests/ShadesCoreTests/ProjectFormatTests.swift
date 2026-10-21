import Foundation
import ShadesCore
import Testing

/// Saved projects must keep opening as the model grows.
struct ProjectFormatTests {
  @Test
  func `a clip saved before text clips and motion blur loads as media following the shutter`(
  ) throws {
    let json = """
      {"id":"6A1F2B4C-0000-4000-8000-000000000001","mediaID":"6A1F2B4C-0000-4000-8000-000000000002",
       "sourceStart":{"value":0,"timescale":600},"duration":{"value":1200,"timescale":600},
       "timelineStart":{"value":0,"timescale":600},"transform":{"x":0,"y":0,"scale":1,"rotation":0},
       "opacity":1,"depth":"inFront","volume":1,"isAudioEnabled":true}
      """
    let clip = try JSONDecoder().decode(Clip.self, from: Data(json.utf8))
    #expect(clip.mediaID == UUID(uuidString: "6A1F2B4C-0000-4000-8000-000000000002"))
    #expect(clip.duration == MediaTime(seconds: 2))
    #expect(clip.motionBlur == 1)
    #expect(clip.footageBlur == false)
  }

  @Test
  func `a timeline saved before the camera, 3D, shorts and shutter loads flat at 180°`() throws {
    let json = """
      {"name":"Main","format":{"width":2880,"height":2160,"framesPerSecond":24},"markers":[],
       "tracks":[{"id":"6A1F2B4C-0000-4000-8000-000000000003","kind":"video","clips":[],
                  "isMuted":false,"isHidden":false},
                 {"id":"6A1F2B4C-0000-4000-8000-000000000004","kind":"text","clips":[],
                  "isMuted":false,"isHidden":false}]}
      """
    let timeline = try JSONDecoder().decode(Timeline.self, from: Data(json.utf8))
    #expect(timeline.camera.isEmpty)
    #expect(timeline.shorts.isEmpty)
    #expect(timeline.shutterAngle == 180)
    #expect(timeline.tracks.map(\.followsCamera) == [true, false])
    let transform = try JSONDecoder().decode(
      ClipTransform.self,
      from: Data(#"{"x":0.1,"y":0,"scale":1,"rotation":0}"#.utf8),
    )
    #expect(transform == ClipTransform(x: 0.1))
  }

  @Test
  func `media and text clips round-trip`() throws {
    let media = Clip(
      mediaID: UUID(),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
      motionBlur: 0.5,
      footageBlur: true,
    )
    let text = Clip(
      source: .text(TextContent(text: "hi")),
      sourceStart: .zero,
      duration: MediaTime(seconds: 1),
      timelineStart: .zero,
    )
    for clip in [media, text] {
      let copy = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(clip))
      #expect(copy == clip)
    }
  }
}
