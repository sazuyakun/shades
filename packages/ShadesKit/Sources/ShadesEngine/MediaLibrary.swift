import AVFoundation
import ShadesCore

// MARK: - MediaLibrary

/// Opens media files for playback once and remembers them, so rebuilding after an edit doesn't
/// reload every file.
@MainActor
final class MediaLibrary {

  // MARK: Internal

  /// The playable tracks of `media`, loading the file the first time it's asked for.
  func tracks(of media: Media) async throws(EngineError) -> MediaTracks {
    if let cached = cache[media.url] {
      return cached
    }
    let asset = AVURLAsset(url: media.url)
    do {
      let video = try await asset.loadTracks(withMediaType: .video).first
      let audio = try await asset.loadTracks(withMediaType: .audio).first
      let rotation = try await video?.load(.preferredTransform) ?? .identity
      let tracks = MediaTracks(asset: asset, video: video, audio: audio, rotation: rotation)
      cache[media.url] = tracks
      return tracks
    } catch {
      logger.error("media.openFailed path=\(media.url.path, privacy: .private)")
      throw .mediaUnreadable(media.url)
    }
  }

  // MARK: Private

  private var cache = [URL: MediaTracks]()

}

// MARK: - MediaTracks

/// A media file's picture and sound, ready to place in a composition.
struct MediaTracks {
  /// Kept because a track doesn't keep its asset alive, and can't be read without it.
  let asset: AVURLAsset
  let video: AVAssetTrack?
  let audio: AVAssetTrack?
  /// The stored-to-upright rotation of the picture.
  let rotation: CGAffineTransform
}
