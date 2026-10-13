import Foundation
import ShadesMedia
import ShadesTestSupport
import Testing

struct MediaLoaderTests {
  @Test
  func `loading a video reads its duration and size`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 1)
    let media = try await MediaLoader.load(url)
    #expect(abs(media.duration.seconds - 1) < 0.05)
    #expect(media.width == 320)
    #expect(media.height == 180)
    #expect(!media.hasAudio)
  }

  @Test
  func `loading a missing file throws fileMissing`() async {
    let url = URL(fileURLWithPath: "/nonexistent/clip.mov")
    await #expect(throws: MediaError.fileMissing(url)) {
      try await MediaLoader.load(url)
    }
  }

  @Test
  func `a thumbnail is no larger than asked`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 255, blue: 0)
    let image = try await MediaLoader.thumbnail(for: url, maxSize: CGSize(width: 160, height: 160))
    #expect(image.width <= 160)
    #expect(image.height <= 160)
  }
}
