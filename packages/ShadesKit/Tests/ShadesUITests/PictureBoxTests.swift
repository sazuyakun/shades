import CoreGraphics
import Foundation
import ShadesCore
@testable import ShadesUI
import Testing

struct PictureBoxTests {

  // MARK: Internal

  @Test
  func `a box over a letterboxed picture lands in the picture's own fractions`() {
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    let box = clip.pictureBox(
      CGRect(x: 0.25, y: 0.125, width: 0.5, height: 0.375),
      media: media,
      format: format,
      at: .zero,
    )
    #expect(abs(box.minX - 0.25) < 0.0001)
    #expect(abs(box.minY) < 0.0001)
    #expect(abs(box.height - 0.5) < 0.0001)
  }

  @Test
  func `a moved, zoomed picture is undone`() {
    var clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    clip.transform.scale = 2
    clip.transform.x = 0.25
    let box = clip.pictureBox(
      CGRect(x: 0.75, y: 0.5, width: 0.1, height: 0.1),
      media: media,
      format: format,
      at: .zero,
    )
    #expect(abs(box.minX - 0.5) < 0.0001)
    #expect(abs(box.width - 0.05) < 0.0001)
  }

  @Test
  func `the part outside the picture is cut off`() {
    let clip = Clip(
      mediaID: media.id,
      sourceStart: .zero,
      duration: seconds(5),
      timelineStart: .zero,
    )
    let box = clip.pictureBox(
      CGRect(x: 0, y: 0, width: 1, height: 0.1),
      media: media,
      format: format,
      at: .zero,
    )
    #expect(box.isEmpty)
  }

  // MARK: Private

  /// A 16:9 picture, fitted inside the 4:3 frame with bars above and below.
  private let media = Media(
    url: URL(filePath: "/tmp/wide.mov"),
    duration: MediaTime(seconds: 5),
    width: 1920,
    height: 1080,
    hasAudio: false,
  )

  private let format = VideoFormat(width: 2880, height: 2160, framesPerSecond: 24)

  private func seconds(_ value: Double) -> MediaTime {
    MediaTime(seconds: value)
  }

}
