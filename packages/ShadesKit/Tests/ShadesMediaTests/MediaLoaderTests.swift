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
  func `a rotated video reports its upright size`() async throws {
    let quarterTurn = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let url = try await VideoFixture.make(left: .red, right: .blue, transform: quarterTurn)
    let media = try await MediaLoader.load(url)
    #expect(media.width == 180)
    #expect(media.height == 320)
  }

  @Test
  func `a sound-only file loads as audio with no picture`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2)
    let media = try await MediaLoader.load(url)
    #expect(!media.hasVideo)
    #expect(media.hasAudio)
    #expect(abs(media.duration.seconds - 2) < 0.01)
  }

  @Test
  func `a filmstrip has the frames asked for, no larger than asked`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 255, seconds: 2)
    let frames = try await MediaLoader.filmstrip(
      for: url,
      count: 4,
      maxSize: CGSize(width: 64, height: 64),
    )
    #expect(frames.count == 4)
    #expect(frames.allSatisfy { $0.width <= 64 && $0.height <= 64 })
  }

  @Test
  func `sound decodes to mono samples at the asked rate`() async throws {
    let url = try AudioFixture.makeTone(seconds: 2)
    let samples = try await AudioDecoder.mono(from: url, sampleRate: 16000)
    #expect(abs(Double(samples.count) - 32000) < 800)
    #expect(samples.contains { abs($0) > 0.3 })
  }

  @Test
  func `decoding a file without sound says so`() async throws {
    let url = try await VideoFixture.make(red: 0, green: 0, blue: 0)
    await #expect(throws: MediaError.noAudio(url)) {
      try await AudioDecoder.mono(from: url, sampleRate: 16000)
    }
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

  @Test
  func `a picture loads as a still with its size, and thumbnails from itself`() async throws {
    let url = try ImageFixture.makeDisc(width: 400, height: 300)
    let media = try await MediaLoader.load(url)
    #expect(media.isStill)
    #expect(media.width == 400 && media.height == 300)
    #expect(!media.hasAudio)
    let thumbnail = try await MediaLoader.thumbnail(
      for: url,
      maxSize: CGSize(width: 100, height: 100),
    )
    #expect(thumbnail.width == 100)
  }
}
