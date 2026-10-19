import CoreGraphics
import ShadesCore
import ShadesExport
import Testing

struct CanvasTests {

  @Test
  func `youtube puts the 4:3 picture at full height in the middle of 3840 by 2160`() {
    #expect(Canvas.youtube.size(for: .standard) == CGSize(width: 3840, height: 2160))
    #expect(Canvas.youtube.pictureRect(for: .standard) == CGRect(
      x: 480,
      y: 0,
      width: 2880,
      height: 2160,
    ))
  }

  @Test
  func `vertical puts the picture 1080 wide in the middle of 1080 by 1920`() {
    #expect(Canvas.vertical.size(for: .standard) == CGSize(width: 1080, height: 1920))
    #expect(Canvas.vertical.pictureRect(for: .standard) == CGRect(
      x: 0,
      y: 555,
      width: 1080,
      height: 810,
    ))
  }

  @Test
  func `canvases keep even sizes for the encoder`() {
    let small = VideoFormat(width: 640, height: 480, framesPerSecond: 24)
    #expect(Canvas.youtube.size(for: small) == CGSize(width: 854, height: 480))
    #expect(Canvas.picture.size(for: small) == CGSize(width: 640, height: 480))
  }

}
