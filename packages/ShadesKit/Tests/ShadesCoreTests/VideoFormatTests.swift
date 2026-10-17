import ShadesCore
import Testing

struct VideoFormatTests {
  @Test
  func `presets are 4:3 at the agreed sizes`() {
    #expect(VideoFormat.standard.width == 2880)
    #expect(VideoFormat.standard.height == 2160)
    #expect(VideoFormat.half.width == 1440)
    #expect(VideoFormat.half.height == 1080)
  }

  @Test
  func `new timelines start at 2880×2160 and 24 fps`() {
    #expect(Timeline().format == .standard)
    #expect(Timeline().format.framesPerSecond == 24)
  }

  @Test
  func `every offered frame rate has a whole number of timeline units per frame`() {
    for rate in VideoFormat.frameRates {
      let frame = VideoFormat.standard.withFrameRate(rate).frameDuration
      #expect(frame.value * Int64(rate) == Int64(MediaTime.timelineTimescale))
    }
  }
}
