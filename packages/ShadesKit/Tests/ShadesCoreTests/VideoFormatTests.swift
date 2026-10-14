import ShadesCore
import Testing

struct VideoFormatTests {
  @Test
  func `presets have the agreed sizes`() {
    #expect(VideoFormat.youTube4x3.width == 1440)
    #expect(VideoFormat.youTube4x3.height == 1080)
    #expect(VideoFormat.reel9x16.width == 1080)
    #expect(VideoFormat.reel9x16.height == 1920)
  }

  @Test
  func `a preset can be made at another frame rate`() {
    #expect(VideoFormat.reel9x16.withFrameRate(60).framesPerSecond == 60)
  }

  @Test
  func `new timelines start as YouTube 4:3 at 30 fps`() {
    #expect(Timeline().format == .youTube4x3)
    #expect(Timeline().format.framesPerSecond == 30)
  }
}
