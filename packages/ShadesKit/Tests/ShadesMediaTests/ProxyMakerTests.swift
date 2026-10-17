import Foundation
import ShadesCore
import ShadesMedia
import ShadesTestSupport
import Testing

struct ProxyMakerTests {
  @Test
  func `only footage larger than 1080p needs a proxy`() {
    let big = Media(
      url: URL(filePath: "/a.mov"),
      duration: .zero,
      width: 3840,
      height: 2160,
      hasAudio: true,
    )
    let small = Media(
      url: URL(filePath: "/b.mov"),
      duration: .zero,
      width: 1920,
      height: 1080,
      hasAudio: true,
    )
    let sound = Media(
      url: URL(filePath: "/c.wav"),
      duration: .zero,
      width: 0,
      height: 0,
      hasVideo: false,
      hasAudio: true,
    )
    #expect(ProxyMaker.needsProxy(big))
    #expect(!ProxyMaker.needsProxy(small))
    #expect(!ProxyMaker.needsProxy(sound))
  }

  @Test
  func `a 4K clip's proxy is 1080p and as long as the original`() async throws {
    let url = try await VideoFixture.make(red: 200, green: 100, blue: 0, width: 3840, height: 2160)
    let original = try await MediaLoader.load(url)
    let proxyURL = ProxyMaker.proxyURL(
      for: original,
      in: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString),
    )
    try await ProxyMaker.makeProxy(of: original, at: proxyURL)
    let proxy = try await MediaLoader.load(proxyURL)
    #expect(max(proxy.width, proxy.height) <= 1920)
    #expect(abs(proxy.duration.seconds - original.duration.seconds) < 0.05)
  }
}
