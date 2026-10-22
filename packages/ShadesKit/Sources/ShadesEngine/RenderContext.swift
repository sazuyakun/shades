import CoreImage
import CoreVideo
import Foundation
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

  // MARK: Public

  /// Why the shader effect at `url` can't be used (its compiler errors), or `nil` if it compiles.
  public func shaderProblem(at url: URL) -> String? {
    renderer.shaderProblem(at: url)
  }

  // MARK: Internal

  let renderer: MetalRenderer

  /// A frame-sized buffer the GPU can draw into, for a picture that's then placed on a canvas.
  static func pictureBuffer(width: Int, height: Int) throws(EngineError) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(
      nil,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      [
        kCVPixelBufferMetalCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
      ] as CFDictionary,
      &buffer,
    )
    guard let buffer else {
      logger.error("frame.renderFailed reason=pictureBuffer width=\(width, privacy: .public)")
      throw .renderFailed
    }
    return buffer
  }

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
    let drawn = DrawnText(
      surface: surface,
      offset: offset,
      solid: content.style.extrusion.flatMap { extrusion in
        solid(extrusion, of: buffer, size: Double(height) * content.style.size)
      },
    )
    texts.withLock { cache in
      if cache.count >= Self.textCacheLimit {
        cache.removeAll()
      }
      cache[key] = drawn
    }
    return drawn
  }

  /// A still picture on a surface for a frame of `width`×`height`, with the sticker look when
  /// given; from the cache when it was drawn recently.
  func still(_ url: URL, look: StickerLook?, width: Int, height: Int) -> IOSurface? {
    let key = StillKey(url: url, look: look, maxSide: max(width, height))
    if let cached = stills.withLock({ $0[key] }) {
      return cached
    }
    guard
      let buffer = StillRenderer.render(url, maxSide: key.maxSide, look: look),
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else {
      logger.error("still.renderFailed path=\(url.path, privacy: .private)")
      return nil
    }
    stills.withLock { cache in
      if cache.count >= Self.stillCacheLimit {
        cache.removeAll()
      }
      cache[key] = surface
    }
    return surface
  }

  /// A drawing as it looks at `time` (seconds into a clip lasting `duration`) on a frame-sized
  /// surface; from the cache when that moment's wobble and drawn length were drawn recently.
  func drawing(
    _ drawing: Drawing,
    at time: Double,
    duration: Double,
    width: Int,
    height: Int,
  ) -> IOSurface? {
    let moment = DrawingRenderer.moment(of: drawing, at: time, duration: duration)
    let key = DrawingKey(drawing: drawing, width: width, height: height, moment: moment)
    if let cached = drawings.withLock({ $0[key] }) {
      return cached
    }
    guard
      let buffer = DrawingRenderer.render(drawing, moment: moment, width: width, height: height),
      let surface = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue()
    else {
      logger.error("drawing.renderFailed width=\(width, privacy: .public)")
      return nil
    }
    drawings.withLock { cache in
      if cache.count >= Self.drawingCacheLimit {
        cache.removeAll()
      }
      cache[key] = surface
    }
    return surface
  }

  /// Draws `picture` scaled into the middle of `canvas`, on black.
  func place(_ picture: CVPixelBuffer, onCanvas canvas: CVPixelBuffer) {
    let canvasSize = CGSize(
      width: CVPixelBufferGetWidth(canvas),
      height: CVPixelBufferGetHeight(canvas),
    )
    let source = CIImage(cvPixelBuffer: picture)
    let scale = min(
      canvasSize.width / source.extent.width,
      canvasSize.height / source.extent.height,
    )
    let placement = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(
      translationX: ((canvasSize.width - source.extent.width * scale) / 2).rounded(),
      y: ((canvasSize.height - source.extent.height * scale) / 2).rounded(),
    ))
    let bounds = CGRect(origin: .zero, size: canvasSize)
    let placed = source.transformed(by: placement, highQualityDownsample: true)
      .composited(over: CIImage(color: .black).cropped(to: bounds))
    canvasImages.render(placed, to: canvas, bounds: bounds, colorSpace: nil)
  }

  // MARK: Private

  /// Drawn texts kept at most; the cache empties when full. Popping words draw a new picture each
  /// frame for a moment, so this holds a few seconds of them.
  private static let textCacheLimit = 256

  /// Pictures kept at most; full-frame stills are large, so only a timeline's worth.
  private static let stillCacheLimit = 32

  /// Drawn moments kept at most: a boiling drawing makes a dozen a second, so a few seconds.
  private static let drawingCacheLimit = 48

  private let texts = Mutex<[TextKey: DrawnText]>([:])

  private let stills = Mutex<[StillKey: IOSurface]>([:])

  private let drawings = Mutex<[DrawingKey: IOSurface]>([:])

  // why: no colour management: frames are already Rec.709 and must come out exactly as drawn.
  private let canvasImages = CIContext(options: [.workingColorSpace: NSNull()])

  /// What makes drawn text `fontSize` pixels high solid letters: its distance field, depth and
  /// bevel in pixels, or `nil` (logged) if the field can't be made.
  private func solid(
    _ extrusion: TextExtrusion,
    of picture: CVPixelBuffer,
    size fontSize: Double,
  ) -> SolidText? {
    let bevel = min(extrusion.bevel, extrusion.depth) * fontSize
    // why: the field's 127 steps each way must reach past the bevel to light it.
    let unit = max(1, (bevel + 4) / 120)
    guard
      let field = DistanceField.make(from: picture, unit: unit),
      let surface = CVPixelBufferGetIOSurface(field)?.takeUnretainedValue()
    else {
      logger.error("text.solidFailed size=\(fontSize, privacy: .public)")
      return nil
    }
    return SolidText(distance: surface, unit: unit, depth: extrusion.depth * fontSize, bevel: bevel)
  }

}

// MARK: - DrawnText

/// A text clip drawn for a frame: its picture, and where its centre goes.
struct DrawnText: Sendable {
  let surface: IOSurface
  /// Offset of its centre from the frame's centre, as fractions of the frame.
  let offset: CGPoint
  /// How to draw it as solid 3D letters, when it's extruded.
  let solid: SolidText?
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

// MARK: - StillKey

/// What a drawn still depends on.
private struct StillKey: Hashable {
  let url: URL
  let look: StickerLook?
  let maxSide: Int
}

// MARK: - DrawingKey

/// What a drawn moment depends on.
private struct DrawingKey: Hashable {
  let drawing: Drawing
  let width: Int
  let height: Int
  let moment: DrawingMoment
}
