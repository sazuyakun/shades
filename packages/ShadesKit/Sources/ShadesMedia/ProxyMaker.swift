import AVFoundation
import ShadesCore

/// Makes light 1080p copies of heavy footage (like 4K HEVC) so editing stays smooth on an 8 GB
/// Mac. Playback uses them; export always uses the originals.
public enum ProxyMaker {

  /// Whether `media` is heavy enough to need a proxy: a picture larger than 1080p.
  public static func needsProxy(_ media: Media) -> Bool {
    media.hasVideo && max(media.width, media.height) > 1920
  }

  /// Where the proxy for `media` lives inside a project's cache folder.
  public static func proxyURL(for media: Media, in cache: URL) -> URL {
    cache.appending(path: "proxies/\(media.id.uuidString).mov")
  }

  /// Writes a 1080p proxy of `media` to `url`, replacing any old one.
  @concurrent
  public static func makeProxy(of media: Media, at url: URL) async throws(MediaError) {
    let asset = AVURLAsset(url: media.url)
    guard
      let session = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPreset1920x1080,
      )
    else {
      logger.error("proxy.failed reason=noSession path=\(media.url.path, privacy: .private)")
      throw .proxyFailed(media.url)
    }
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
      )
      // why: there may be no old proxy; that's the common case.
      try? FileManager.default.removeItem(at: url)
      try await session.export(to: url, as: .mov)
    } catch {
      logger.error("proxy.failed reason=export path=\(media.url.path, privacy: .private)")
      throw .proxyFailed(media.url)
    }
  }

}
