import CoreVideo
import IOSurface
import Synchronization

/// The GPU setup shared by everything that draws frames (the player, frame grabs for Claude):
/// made once, because compiling shaders and opening the GPU is slow. It also keeps recently
/// drawn captions (their GPU surfaces), so text isn't re-rendered every frame.
public final class RenderContext: Sendable {

  // MARK: Lifecycle

  /// Opens the GPU and compiles the shaders.
  public init() throws(EngineError) {
    renderer = try MetalRenderer()
  }

  // MARK: Internal

  let renderer: MetalRenderer

  /// `text` drawn as a caption on a transparent `width`×`height` surface, from the cache when
  /// it was drawn recently.
  func caption(_ text: String, width: Int, height: Int) -> IOSurface? {
    let key = "\(width)x\(height):\(text)"
    if let cached = captions.withLock({ $0[key] }) {
      return cached
    }
    guard
      let drawn = TextRenderer.caption(text, width: width, height: height),
      let surface = CVPixelBufferGetIOSurface(drawn)?.takeUnretainedValue()
    else {
      logger
        .error(
          "caption.renderFailed width=\(width, privacy: .public) height=\(height, privacy: .public)"
        )
      return nil
    }
    captions.withLock { cache in
      if cache.count >= Self.captionCacheLimit {
        cache.removeAll()
      }
      cache[key] = surface
    }
    return surface
  }

  // MARK: Private

  /// Captions kept at most; the cache empties when full (a timeline rarely shows more at once).
  private static let captionCacheLimit = 64

  private let captions = Mutex<[String: IOSurface]>([:])

}
