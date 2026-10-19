import CoreVideo
import IOSurface
import ShadesCore
import Synchronization

// MARK: - RenderContext

/// The GPU setup shared by everything that draws frames (the player, frame grabs for Claude):
/// made once, because compiling shaders and opening the GPU is slow. It also keeps recently
/// drawn text (its GPU surfaces), so text isn't re-rendered every frame.
public final class RenderContext: Sendable {

  // MARK: Lifecycle

  /// Opens the GPU and compiles the shaders.
  public init() throws(EngineError) {
    renderer = try MetalRenderer()
  }

  // MARK: Internal

  let renderer: MetalRenderer

  /// A text clip drawn as it looks at `time` (seconds into its source) on a transparent surface
  /// at the scale of a `width`×`height` frame, and where its centre sits (offset from the frame's
  /// centre, as fractions). From the cache when it was drawn the same way recently.
  func text(
    _ content: TextContent,
    at time: Double,
    duration: Double,
    width: Int,
    height: Int,
  ) -> DrawnText? {
    let (states, state) = TextRenderer.wordStates(of: content, at: time, duration: duration)
    let key = TextKey(content: content, width: width, height: height, state: state)
    if let cached = texts.withLock({ $0[key] }) {
      return cached
    }
    guard
      let (buffer, offset) = TextRenderer.render(
        content,
        states: states,
        frameWidth: width,
        frameHeight: height,
      ),
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else {
      logger
        .error(
          "text.renderFailed width=\(width, privacy: .public) height=\(height, privacy: .public)"
        )
      return nil
    }
    let drawn = DrawnText(surface: surface, offset: offset)
    texts.withLock { cache in
      if cache.count >= Self.textCacheLimit {
        cache.removeAll()
      }
      cache[key] = drawn
    }
    return drawn
  }

  // MARK: Private

  /// Drawn texts kept at most; the cache empties when full. Popping words draw a new picture each
  /// frame for a moment, so this holds a few seconds of them.
  private static let textCacheLimit = 256

  private let texts = Mutex<[TextKey: DrawnText]>([:])

}

// MARK: - DrawnText

/// A text clip drawn for a frame: its picture, and where its centre goes.
struct DrawnText: Sendable {
  let surface: IOSurface
  /// Offset of its centre from the frame's centre, as fractions of the frame.
  let offset: CGPoint
}

// MARK: - TextKey

/// What a drawn text depends on.
private struct TextKey: Hashable {
  let content: TextContent
  let width: Int
  let height: Int
  /// How its words are revealed at that moment.
  let state: String
}
